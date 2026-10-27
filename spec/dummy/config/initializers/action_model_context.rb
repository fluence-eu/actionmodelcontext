Rails.application.config.action_model_context.oauth.resource = 'https://example.com/mcp'
Rails.application.config.action_model_context.oauth.authorization_servers = [ 'https://auth.example.com' ]
Rails.application.config.action_model_context.oauth.scopes = %w[mcp:tools]
