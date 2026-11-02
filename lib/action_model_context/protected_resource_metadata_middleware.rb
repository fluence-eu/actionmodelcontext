module ActionModelContext
  # The SDK answers only when PATH_INFO is the RFC 9728 path built from the public resource URL, prefix included
  # (/.well-known/oauth-protected-resource/<prefix>/mcp), which an app mounted under that prefix never receives.
  #
  # @api private
  class ProtectedResourceMetadataMiddleware < MCP::Server::OAuth::ProtectedResourceMetadataMiddleware
    # The path of the metadata document, relative to the app.
    PATH = '/.well-known/oauth-protected-resource'

    # Keeps the path the SDK expects.
    #
    # @param app [#call] the next Rack application
    # @param metadata [MCP::Server::OAuth::ProtectedResourceMetadata] the document to serve
    def initialize(app, metadata)
      super
      @sdk_path = metadata.well_known_path
    end

    # Serves the document at {PATH} too.
    #
    # @param env [Hash] the Rack environment
    # @return [Array(Integer, Hash, #each)] the Rack response
    def call(env)
      env = env.merge('PATH_INFO' => @sdk_path) if env['PATH_INFO'] == PATH
      super
    end
  end
end
