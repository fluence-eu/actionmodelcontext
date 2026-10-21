require "active_support/core_ext/class/attribute"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/enumerable"

module ActionModelContext
  class Tool
    ARGUMENT_TYPES = %i[string integer number boolean array object].freeze

    class_attribute :declared_description, :declared_title, :declared_tool_name, :declared_annotations,
                    instance_accessor: false, instance_predicate: false
    class_attribute :arguments, instance_accessor: false, instance_predicate: false, default: {}.freeze

    class << self
      def description(text = nil)
        return self.declared_description = text if text

        declared_description || Translation.lookup(:tools, tool_name, :description)
      end

      def title(text = nil)
        return self.declared_title = text if text

        declared_title || Translation.lookup(:tools, tool_name, :title)
      end

      def tool_name(name = nil)
        return self.declared_tool_name = name if name

        declared_tool_name || Naming.default_name(self, suffix: "Tool")
      end

      def argument(name, type, required: false, description: nil, enum: nil, items: nil, properties: nil)
        raise ArgumentError, "unknown argument type #{type.inspect}" unless ARGUMENT_TYPES.include?(type)

        self.arguments = arguments.merge(name.to_sym => { type:, required:, description:, enum:, items:, properties: }).freeze
      end

      def argument_names = arguments.keys

      def annotations(**hints)
        return declared_annotations if hints.empty?

        self.declared_annotations = hints
      end

      def to_mcp(context:)
        tool = self
        MCP::Tool.define(
          name: tool_name, title:, description:, input_schema: input_schema, annotations: declared_annotations,
        ) { |server_context: nil, **args| tool.new(context: server_context).call_mcp(args) }
      end

      private

      def input_schema
        properties = arguments.to_h { |name, spec| [ name, property_schema(name, spec) ] }
        required = arguments.select { |_, spec| spec[:required] }.keys.map(&:to_s)
        { type: "object", properties:, required: }.compact_blank
      end

      def property_schema(name, spec)
        description = spec[:description] || Translation.lookup(:tools, tool_name, :arguments, name)
        { type: spec[:type].to_s, description:, enum: spec[:enum], items: spec[:items], properties: spec[:properties] }.compact
      end
    end
  end
end
