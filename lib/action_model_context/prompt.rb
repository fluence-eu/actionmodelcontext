require "active_support/core_ext/class/attribute"

module ActionModelContext
  class Prompt
    include Primitive

    primitive kind: :prompts, suffix: "Prompt"

    class_attribute :arguments, instance_accessor: false, instance_predicate: false, default: {}.freeze

    class << self
      def prompt_name(name = nil) = primitive_name(name)

      def argument(name, required: false, description: nil)
        self.arguments = arguments.merge(name.to_sym => { required:, description: }).freeze
      end

      def argument_names = arguments.keys

      def to_mcp(context:)
        prompt = self
        MCP::Prompt.define(name: prompt_name, title:, description:, arguments: mcp_arguments) do |args, **|
          prompt.new(context:).call_mcp(args || {})
        end
      end

      private

      def mcp_arguments
        arguments.map do |name, spec|
          description = spec[:description] || Translation.lookup(i18n_kind, prompt_name, :arguments, name)
          MCP::Prompt::Argument.new(name: name.to_s, description:, required: spec[:required])
        end
      end
    end

    def call(**) = raise(NotImplementedError, "#{self.class.name}#call is not implemented")

    def call_mcp(arguments)
      to_result(with_rescue { call(**arguments.slice(*self.class.argument_names)) })
    rescue Error => e
      raise_invalid_params(e)
    end

    private

    def to_result(result)
      messages = case result
      when String then [ message("user", result) ]
      when Array then result.map { |item| message(item.fetch(:role), item.fetch(:content)) }
      else raise TypeError, "#{self.class.name}#call must return a String or Array, got #{result.class}"
      end
      MCP::Prompt::Result.new(messages:)
    end

    def message(role, text) = MCP::Prompt::Message.new(role:, content: MCP::Content::Text.new(text))
  end
end
