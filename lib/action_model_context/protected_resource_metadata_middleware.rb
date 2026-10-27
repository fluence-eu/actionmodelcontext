module ActionModelContext
  # The SDK answers only when PATH_INFO is the RFC 9728 path built from the public resource URL, prefix included
  # (/.well-known/oauth-protected-resource/<prefix>/mcp), which an app mounted under that prefix never receives.
  class ProtectedResourceMetadataMiddleware < MCP::Server::OAuth::ProtectedResourceMetadataMiddleware
    PATH = '/.well-known/oauth-protected-resource'

    def initialize(app, metadata)
      super
      @sdk_path = metadata.well_known_path
    end

    def call(env)
      env = env.merge('PATH_INFO' => @sdk_path) if env['PATH_INFO'] == PATH
      super
    end
  end
end
