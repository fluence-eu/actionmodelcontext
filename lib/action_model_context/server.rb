require 'active_support/concern'

module ActionModelContext
  module Server
    extend ActiveSupport::Concern

    included do
      skip_forgery_protection only: %i[show create destroy] if respond_to?(:skip_forgery_protection)
      before_action :verify_mcp_access_token, only: %i[show create destroy], if: -> { mcp_oauth.verifier }
    end

    def self.discover(base_name, dir)
      path = Rails.root.join('app/mcp', dir)
      Rails.autoloaders.main.eager_load_dir(path) if path.directory?
      base_name.safe_constantize&.descendants&.select(&:concrete?) || []
    end

    def show = serve_mcp
    def create = serve_mcp
    def destroy = serve_mcp

    private

    def mcp_context = {}
    def mcp_server_options = { name: Rails.application.class.module_parent_name.underscore }
    def mcp_transport_options = {}

    def request_mcp_authentication
      render_mcp_challenge(MCP::Server::OAuth::Challenge.missing_token_response(scope: mcp_oauth.scopes&.join(' '), resource_metadata: mcp_resource_metadata_url))
    end

    def mcp_access_token = request.env[MCP::Server::OAuth::ENV_KEY]

    def verify_mcp_access_token
      authenticator = MCP::Server::OAuth::Authenticator.new(
        token_verifier: mcp_oauth.verifier, required_scopes: mcp_oauth.scopes,
        resource_metadata: mcp_oauth.metadata, resource_metadata_url: mcp_resource_metadata_url,
      )
      request.env[MCP::Server::OAuth::ENV_KEY] = authenticator.authenticate(request.env)
    rescue MCP::Server::OAuth::Error => e
      render_mcp_challenge(authenticator.challenge_response(e))
    end

    def mcp_oauth = Rails.configuration.action_model_context.oauth

    # A proxy can strip the path prefix and pass on only X-Forwarded-Host, leaving SCRIPT_NAME empty:
    # the public URL declared in resource is then the one place that still holds the prefix.
    def mcp_resource_metadata_url
      resource = mcp_oauth.resource
      return "#{resource.delete_suffix(request.path_info)}#{ProtectedResourceMetadataMiddleware::PATH}" if resource&.end_with?(request.path_info)

      "#{request.base_url}#{request.script_name}#{ProtectedResourceMetadataMiddleware::PATH}"
    end

    def render_mcp_challenge(challenge)
      self.status, challenge_headers, self.response_body = challenge
      headers.merge!(challenge_headers)
    end

    # handle_request, not call(env): Rails already read the body into RAW_POST_DATA to log params, and only
    # ActionDispatch::Request#body replays it when rack.input cannot rewind (optional since Rack 3).
    def serve_mcp
      self.status, transport_headers, self.response_body = mcp_transport.handle_request(request)
      headers.merge!(transport_headers)
    end

    def mcp_transport
      context = mcp_context
      templates, resources = Server.discover('ApplicationResource', 'resources').partition(&:template?)
      server = MCP::Server.new(
        **mcp_server_options,
        tools: Server.discover('ApplicationTool', 'tools').map { |tool| tool.to_mcp(context:) },
        resources: resources.map { |resource| resource.to_mcp(context:) },
        resource_templates: templates.map { |template| template.to_mcp(context:) },
        prompts: Server.discover('ApplicationPrompt', 'prompts').map { |prompt| prompt.to_mcp(context:) },
        capabilities: { tools: {}, resources: {}, prompts: {} },
      )
      # Host checking is left to Rails' config.hosts: the transport's own check rejects every Host but 127.0.0.1,
      # ::1 and localhost. The structural options come last because stateless: false starts one session reaper
      # thread per request that nothing ever closes.
      MCP::Server::Transports::StreamableHTTPTransport.new(
        server, dns_rebinding_protection: false, **mcp_transport_options,
        stateless: true, enable_json_response: true, serve_subscriptions_listen: false,
      )
    end
  end
end
