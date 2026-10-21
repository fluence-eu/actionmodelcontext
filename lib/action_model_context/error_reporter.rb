module ActionModelContext
  module ErrorReporter
    # The SDK reports an internal failure as its original exception (mcp server.rb:779), so a bare
    # RequestHandlerError or OAuth::Error is the client's fault: "Tool not found", a missing scope.
    def self.call(exception, _server_context)
      return if exception.is_a?(MCP::Server::RequestHandlerError) || exception.is_a?(MCP::Server::OAuth::Error)

      Rails.error.report(exception, handled: true, severity: :error, source: "actionmodelcontext")
    end
  end
end
