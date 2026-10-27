module ActionModelContext
  class Railtie < Rails::Railtie
    config.action_model_context = ActiveSupport::OrderedOptions.new
    config.action_model_context.oauth = ActiveSupport::OrderedOptions.new

    initializer 'action_model_context.autoload' do |app|
      Rails.autoloaders.main.collapse(app.root.join('app/mcp/*').to_s)
    end

    initializer 'action_model_context.exception_reporter' do
      MCP.configure { |config| config.exception_reporter = ErrorReporter }
    end

    initializer 'action_model_context.oauth', after: :load_config_initializers do |app|
      oauth = app.config.action_model_context.oauth
      raise ArgumentError, 'config.action_model_context.oauth.token_verifier requires oauth.resource' if oauth.token_verifier && !oauth.resource
      next unless oauth.resource

      oauth.metadata = MCP::Server::OAuth::ProtectedResourceMetadata.new(
        resource: oauth.resource, authorization_servers: oauth.authorization_servers, scopes_supported: oauth.scopes,
        resource_name: oauth.resource_name, resource_documentation: oauth.resource_documentation, extra: oauth.extra || {},
      )
      app.middleware.use ProtectedResourceMetadataMiddleware, oauth.metadata
    end

    # The verifier may name an app class, which cannot autoload while initializers run: DoorkeeperTokenVerifier in app/mcp.
    config.to_prepare do
      oauth = Rails.application.config.action_model_context.oauth
      oauth.verifier = oauth.token_verifier&.call(oauth.metadata)
    end
  end
end
