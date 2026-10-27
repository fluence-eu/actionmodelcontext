Rails.application.config.action_model_context.oauth.resource = 'https://example.com/backend/app/mcp'
Rails.application.config.action_model_context.oauth.authorization_servers = [ 'https://auth.example.com' ]
Rails.application.config.action_model_context.oauth.scopes = %w[mcp:tools]
