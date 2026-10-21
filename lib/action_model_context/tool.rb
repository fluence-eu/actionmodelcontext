require "active_support/core_ext/class/attribute"
require "active_support/rescuable"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/object/blank"

module ActionModelContext
  class Tool
    include Primitive

    primitive kind: :tools, suffix: "Tool"

    ARGUMENT_TYPES = %i[string integer number boolean array object].freeze

    class_attribute :declared_annotations, instance_accessor: false, instance_predicate: false
    class_attribute :arguments, instance_accessor: false, instance_predicate: false, default: {}.freeze

    class << self
      def tool_name(name = nil) = primitive_name(name)

      def argument(name, type, required: false, description: nil, enum: nil, items: nil, properties: nil)
        raise ArgumentError, "unknown argument type #{type.inspect}" unless ARGUMENT_TYPES.include?(type)

        self.arguments = arguments.merge(name.to_sym => { type:, required:, description:, enum:, items:, properties: }).freeze
      end

      def argument_names = arguments.keys

      def concrete? = instance_method(:call).owner != Tool

      def annotations(**hints)
        return declared_annotations if hints.empty?

        self.declared_annotations = hints
      end

      def to_mcp(context:)
        tool = self
        MCP::Tool.define(
          name: tool_name, title:, description:, input_schema:, annotations: declared_annotations,
        ) { |**args| tool.new(context:).call_mcp(args.except(:server_context)) }
      end

      private

      def input_schema
        properties = arguments.to_h { |name, spec| [ name, property_schema(name, spec) ] }
        required = arguments.select { |_, spec| spec[:required] }.keys.map(&:to_s)
        { type: "object", properties:, required: }.compact_blank
      end

      def property_schema(name, spec)
        description = spec[:description] || Translation.lookup(i18n_kind, tool_name, :arguments, name)
        { type: spec[:type].to_s, description:, enum: spec[:enum], items: spec[:items], properties: spec[:properties] }.compact
      end
    end

    def call(**) = raise(NotImplementedError, "#{self.class.name}#call is not implemented")

    def call_mcp(arguments)
      to_response(invoke(arguments))
    rescue Error => e
      MCP::Tool::Response.new([ { type: "text", text: e.message } ], error: true)
    end

    private

    def invoke(arguments)
      with_rescue { call(**arguments.slice(*self.class.argument_names)) }
    end

    def to_response(result)
      case result
      when MCP::Tool::Response then result
      when String then MCP::Tool::Response.new([ { type: "text", text: result } ])
      when Hash then MCP::Tool::Response.new([ { type: "text", text: result.to_json } ], structured_content: result)
      when Array then MCP::Tool::Response.new([ { type: "text", text: result.to_json } ])
      else raise TypeError, "#{self.class.name}#call or its rescue_from handler must return a String, Hash, Array or MCP::Tool::Response, got #{result.class}"
      end
    end
  end
end
