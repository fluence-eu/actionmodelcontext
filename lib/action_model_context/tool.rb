require 'active_support/core_ext/class/attribute'
require 'active_support/rescuable'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/object/blank'

module ActionModelContext
  # Base class of the tools. An application subclasses it through `ApplicationTool`, under `app/mcp/tools`.
  #
  # @example
  #   class EchoTool < ApplicationTool
  #     argument :message, :string, required: true
  #     argument :times, :integer
  #
  #     def call(message:, times: 1) = message * times
  #   end
  #
  # @api public
  class Tool
    include Primitive

    primitive kind: :tools, suffix: 'Tool'

    # The types {argument} accepts.
    ARGUMENT_TYPES = %i[string integer number boolean array object].freeze
    # @api private
    ARGUMENT_OPTIONS = %i[required null].freeze
    # JSON Schema 2020-12, the dialect MCP mandates (SEP-1613), minus type and required that argument sets itself.
    SCHEMA_KEYWORDS = %w[
      $id $schema $ref $anchor $dynamicRef $dynamicAnchor $vocabulary $comment $defs
      prefixItems items contains additionalProperties properties patternProperties dependentSchemas propertyNames
      if then else allOf anyOf oneOf not unevaluatedItems unevaluatedProperties
      const enum multipleOf maximum exclusiveMaximum minimum exclusiveMinimum maxLength minLength pattern
      maxItems minItems uniqueItems maxContains minContains maxProperties minProperties dependentRequired
      title description default deprecated readOnly writeOnly examples format contentEncoding contentMediaType contentSchema
    ].freeze

    class_attribute :declared_annotations, instance_accessor: false, instance_predicate: false
    class_attribute :arguments, instance_accessor: false, instance_predicate: false, default: {}.freeze

    class << self
      # Declares the name, or reads it.
      #
      # @param name [String, nil] the name to declare
      # @return [String, nil] the declared name, else the underscored class name without its `Tool` suffix
      def tool_name(name = nil) = primitive_name(name)

      # Declares an argument of the input schema.
      #
      # @example
      #   argument :ids, :array, required: true, items: { type: 'integer' }, max_items: 50
      #
      # @param name [Symbol, String] the argument's name
      # @param type [Symbol] one of {ARGUMENT_TYPES}
      # @param keywords [Hash] any JSON Schema 2020-12 keyword, in snake_case or camelCase
      # @option keywords [Boolean] :required (false) whether the client must send it
      # @option keywords [Boolean] :null (false) whether it also accepts `null`
      # @return [void]
      # @raise [ArgumentError] when the type or a keyword is unknown
      def argument(name, type, **keywords)
        raise ArgumentError, "unknown argument type #{type.inspect}" unless ARGUMENT_TYPES.include?(type)

        unknown = keywords.keys.reject { |key| ARGUMENT_OPTIONS.include?(key) || SCHEMA_KEYWORDS.include?(key.to_s.camelize(:lower)) }
        raise ArgumentError, "unknown JSON Schema keyword #{unknown.first.inspect} for argument #{name.inspect}" if unknown.any?

        self.arguments = arguments.merge(name.to_sym => keywords.merge(type:)).freeze
      end

      # Declares one argument per entry of a JSON Schema `properties` hash, `type: [..., 'null']` becoming `null: true`.
      #
      # @example
      #   arguments_from({ title: { type: 'string' }, due_on: { type: %w[string null] } }, required: %i[title])
      #
      # @param properties [Hash{Symbol, String => Hash}] the schema of each argument
      # @param required [Array<Symbol, String>] the names of the required arguments
      # @return [void]
      # @raise [ArgumentError] when a property has no single type, lists its own `required` or takes an unknown keyword
      def arguments_from(properties, required: [])
        required = required.map(&:to_s)
        properties.each do |name, schema|
          schema = schema.symbolize_keys
          raise ArgumentError, "argument #{name.to_sym.inspect} lists its own required properties, which argument cannot express" if schema.key?(:required)

          types = Array(schema[:type]).map(&:to_s)
          null = types.delete('null').present?
          raise ArgumentError, "argument #{name.to_sym.inspect} needs a single type, got #{schema[:type].inspect}" unless types.one?

          argument(name, types.first.to_sym, required: required.include?(name.to_s), null:, **schema.except(:type))
        end
      end

      # Lists the declared arguments.
      #
      # @return [Array<Symbol>]
      # @api private
      def argument_names = arguments.keys

      # Tells whether the tool is exposed, which takes a `call` below this class.
      #
      # @return [Boolean]
      # @api private
      def concrete? = instance_method(:call).owner != Tool

      # Declares the annotations, or reads them.
      #
      # @param hints [Hash] the keywords of `MCP::Tool::Annotations`, such as `read_only_hint: true`
      # @return [Hash, nil] nil when none are declared
      def annotations(**hints)
        return declared_annotations if hints.empty?

        self.declared_annotations = hints
      end

      # Builds the SDK tool for a request.
      #
      # @param context [Object] the context of the request
      # @return [Class<MCP::Tool>]
      # @api private
      def to_mcp(context:)
        tool = self
        MCP::Tool.define(
          name: tool_name, title:, description:, input_schema:, annotations: declared_annotations,
        ) { |**args| tool.new(context:).call_mcp(args.except(:server_context)) }
      end

      private

      # Builds the JSON Schema of the arguments.
      #
      # @return [Hash]
      # @api private
      def input_schema
        properties = arguments.to_h { |name, spec| [ name, property_schema(name, spec) ] }
        required = arguments.select { |_, spec| spec[:required] }.keys.map(&:to_s)
        { type: 'object', properties:, required: }.compact_blank
      end

      # Builds the JSON Schema of an argument, its description falling back on I18n.
      #
      # @param name [Symbol] the argument's name
      # @param spec [Hash] its declaration
      # @return [Hash]
      # @api private
      def property_schema(name, spec)
        type = spec[:null] ? [ spec[:type].to_s, 'null' ] : spec[:type].to_s
        keywords = spec.except(*ARGUMENT_OPTIONS).transform_keys { |key| key.to_s.camelize(:lower).to_sym }
        description = keywords[:description] || Translation.argument(i18n_kind, tool_name, name, :description)
        { **keywords, type:, description: }.compact
      end
    end

    # Runs the tool. A subclass defines it, with one keyword per argument it takes.
    #
    # @return [String, Hash, Array, MCP::Tool::Response] the result, a `Hash` also going out as structured content
    # @raise [Error] to answer an error result with its message
    # @raise [NotImplementedError] when no subclass defines it
    def call(**) = raise(NotImplementedError, "#{self.class.name}#call is not implemented")

    # Runs the tool for the SDK.
    #
    # @param arguments [Hash] the arguments the client sent
    # @return [MCP::Tool::Response]
    # @api private
    def call_mcp(arguments)
      to_response(with_rescue { invoke(arguments) })
    rescue Error => e
      MCP::Tool::Response.new([ { type: 'text', text: e.message } ], error: true)
    end

    private

    # Wraps every call of the tool: override this private method and call `super`, as `process_action` in a
    # controller. `rescue_from` covers it.
    #
    # @!visibility public
    # @param arguments [Hash] the arguments as the client sent them, before they are sliced to the declared ones
    # @return [Object] the value of {#call}, before its conversion
    def invoke(arguments) = call(**arguments.slice(*self.class.argument_names))

    # Converts the value of {#call}.
    #
    # @param result [String, Hash, Array, MCP::Tool::Response] that value
    # @return [MCP::Tool::Response]
    # @raise [TypeError] when the value is of another class
    # @api private
    def to_response(result)
      case result
      when MCP::Tool::Response then result
      when String then MCP::Tool::Response.new([ { type: 'text', text: result } ])
      when Hash then MCP::Tool::Response.new([ { type: 'text', text: result.to_json } ], structured_content: result)
      when Array then MCP::Tool::Response.new([ { type: 'text', text: result.to_json } ])
      else raise TypeError, "#{self.class.name}#call or its rescue_from handler must return a String, Hash, Array or MCP::Tool::Response, got #{result.class}"
      end
    end
  end
end
