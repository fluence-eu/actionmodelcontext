require "action_model_context"

module ActionModelContext
  module TestHelper
    Result = Data.define(:text, :structured_content, :error) do
      def error? = error
    end

    def call_tool(tool_class, context: {}, **arguments)
      raised = []
      server = MCP::Server.new(
        tools: [ tool_class.to_mcp(context:) ],
        configuration: MCP::Configuration.new(exception_reporter: ->(exception, _) { raised << exception }),
      )
      response = server.handle(
        { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: tool_class.tool_name, arguments: } },
      )
      raise raised.first if response[:error] && raised.any?

      result = response.fetch(:result)
      Result.new(
        text: result[:content].filter_map { |part| part[:text] if part[:type] == "text" }.join,
        structured_content: result[:structuredContent],
        error: result[:isError] == true,
      )
    end
  end
end
