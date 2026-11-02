require 'active_support/core_ext/class/attribute'

module ActionModelContext
  # Base class of the prompts. An application subclasses it through `ApplicationPrompt`, under `app/mcp/prompts`.
  #
  # @example
  #   class SummarizePrompt < ApplicationPrompt
  #     argument :topic, required: true
  #
  #     def call(topic:) = "Summarize #{topic} in three points"
  #   end
  #
  # @api public
  class Prompt
    include Primitive

    primitive kind: :prompts, suffix: 'Prompt'

    class_attribute :arguments, instance_accessor: false, instance_predicate: false, default: {}.freeze

    class << self
      # Declares the name, or reads it.
      #
      # @param name [String, nil] the name to declare
      # @return [String, nil] the declared name, else the underscored class name without its `Prompt` suffix
      def prompt_name(name = nil) = primitive_name(name)

      # Declares an argument. MCP gives a prompt argument no type, only these fields.
      #
      # @param name [Symbol, String] the argument's name
      # @param required [Boolean] whether the client must send it
      # @param title [String, nil] its title, falling back on I18n
      # @param description [String, nil] its description, falling back on I18n
      # @return [void]
      def argument(name, required: false, title: nil, description: nil)
        self.arguments = arguments.merge(name.to_sym => { required:, title:, description: }).freeze
      end

      # Lists the declared arguments.
      #
      # @return [Array<Symbol>]
      # @api private
      def argument_names = arguments.keys

      # Tells whether the prompt is exposed, which takes a `call` below this class.
      #
      # @return [Boolean]
      # @api private
      def concrete? = instance_method(:call).owner != Prompt

      # Builds the SDK prompt for a request.
      #
      # @param context [Object] the context of the request
      # @return [Class<MCP::Prompt>]
      # @api private
      def to_mcp(context:)
        prompt = self
        MCP::Prompt.define(name: prompt_name, title:, description:, arguments: mcp_arguments) do |args, **|
          prompt.new(context:).call_mcp(args || {})
        end
      end

      private

      # Builds the SDK arguments, their title and description falling back on I18n.
      #
      # @return [Array<MCP::Prompt::Argument>]
      # @api private
      def mcp_arguments
        arguments.map do |name, spec|
          title = spec[:title] || Translation.argument(i18n_kind, prompt_name, name, :title)
          description = spec[:description] || Translation.argument(i18n_kind, prompt_name, name, :description)
          MCP::Prompt::Argument.new(name: name.to_s, title:, description:, required: spec[:required])
        end
      end
    end

    # Builds the prompt. A subclass defines it, with one keyword per argument it takes.
    #
    # @return [String, Array<Hash>] one user message, or `{ role:, content: }` hashes
    # @raise [Error] to answer an `invalid_params` JSON-RPC error
    # @raise [NotImplementedError] when no subclass defines it
    def call(**) = raise(NotImplementedError, "#{self.class.name}#call is not implemented")

    # Builds the prompt for the SDK.
    #
    # @param arguments [Hash] the arguments the client sent
    # @return [MCP::Prompt::Result]
    # @raise [MCP::Server::RequestHandlerError] when the prompt raises {Error}
    # @api private
    def call_mcp(arguments)
      to_result(with_rescue { call(**arguments.slice(*self.class.argument_names)) })
    rescue Error => e
      raise_invalid_params(e)
    end

    private

    # Converts the value of {#call}.
    #
    # @param result [String, Array<Hash>] that value
    # @return [MCP::Prompt::Result]
    # @raise [TypeError] when the value is of another class
    # @api private
    def to_result(result)
      messages = case result
      when String then [ message('user', result) ]
      when Array then result.map { |item| message(item.fetch(:role), item.fetch(:content)) }
      else raise TypeError, "#{self.class.name}#call or its rescue_from handler must return a String or Array, got #{result.class}"
      end
      MCP::Prompt::Result.new(messages:)
    end

    # Builds a text message.
    #
    # @param role [String] the role of the message
    # @param text [String] its text
    # @return [MCP::Prompt::Message]
    # @api private
    def message(role, text) = MCP::Prompt::Message.new(role:, content: MCP::Content::Text.new(text))
  end
end
