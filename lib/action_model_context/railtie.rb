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
      next unless oauth.resource

      metadata = MCP::Server::OAuth::ProtectedResourceMetadata.new(
        resource: oauth.resource, authorization_servers: oauth.authorization_servers, scopes_supported: oauth.scopes,
      )
      app.middleware.use ProtectedResourceMetadataMiddleware, metadata
    end
  end
end
