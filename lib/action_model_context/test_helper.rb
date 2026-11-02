require 'action_model_context'

module ActionModelContext
  # Runs a tool in a test through a real `MCP::Server`, so argument validation and error handling behave as in
  # production.
  #
  # @example
  #   include ActionModelContext::TestHelper
  #
  #   result = call_tool(EchoTool, message: 'hi', times: 2)
  #   result.text #=> 'hihi'
  #
  # @api public
  module TestHelper
    # What {TestHelper#call_tool} returns.
    #
    # @!attribute [r] text
    #   The text parts of the result, joined.
    #   @return [String]
    #   @api public
    # @!attribute [r] structured_content
    #   The structured content of the result.
    #   @return [Hash, nil]
    #   @api public
    # @!attribute [r] error
    #   Whether the tool answered an error result.
    #   @return [Boolean]
    #   @api public
    Result = Data.define(:text, :structured_content, :error) do
      # Tells whether the tool answered an error result.
      #
      # @return [Boolean]
      def error? = error
    end

    # Calls a tool. An unexpected exception raised by the tool is raised again here.
    #
    # @param tool_class [Class] a subclass of {Tool}
    # @param context [Object] the context given to the tool
    # @param arguments [Hash] the arguments of the tool
    # @return [Result]
    def call_tool(tool_class, context: {}, **arguments)
      raised = []
      server = MCP::Server.new(
        tools: [ tool_class.to_mcp(context:) ],
        configuration: MCP::Configuration.new(exception_reporter: ->(exception, _) { raised << exception }),
      )
      response = server.handle(
        { jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: tool_class.tool_name, arguments: } },
      )
      raise raised.first if response[:error] && raised.any?

      result = response.fetch(:result)
      Result.new(
        text: result[:content].filter_map { |part| part[:text] if part[:type] == 'text' }.join,
        structured_content: result[:structuredContent],
        error: result[:isError] == true,
      )
    end
  end
end
