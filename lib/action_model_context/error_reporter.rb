module ActionModelContext
  module ErrorReporter
    # The SDK reports an internal failure as its original exception (mcp server.rb:779), so a bare
    # RequestHandlerError or OAuth::Error is the client's fault: "Tool not found", a missing scope.
    def self.call(exception, server_context)
      return if exception.is_a?(MCP::Server::RequestHandlerError) || exception.is_a?(MCP::Server::OAuth::Error)

      Rails.error.report(exception, handled: true, severity: :error, source: 'actionmodelcontext', context: request_context(server_context[:request]))
    end

    # The legacy lifecycle hands over the raw JSON body, a batch included. The arguments stay out: they may carry personal data.
    private_class_method def self.request_context(request)
      request = JSON.parse(request, symbolize_names: true) if request.is_a?(String)
      params = request[:params] if request.is_a?(Hash)
      return {} unless params.is_a?(Hash)

      { mcp_method: request[:method], mcp_name: params[:name] || params[:uri] }.compact
    end
  end
end
