require 'rails_helper'
require 'rack/mock'

RSpec.describe 'OAuth protected resource', type: :request do
  it 'serves the metadata document configured under config.action_model_context.oauth' do
    get '/.well-known/oauth-protected-resource'
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      'resource' => 'https://example.com/mcp', 'authorization_servers' => [ 'https://auth.example.com' ], 'scopes_supported' => [ 'mcp:tools' ],
    )
  end

  it 'answers 401 with a challenge naming the document under the prefix of the request' do
    controller = stub_const('GuardedMcpController', Class.new(McpController) { before_action { request_mcp_authentication } })
    response = Rack::MockRequest.new(controller.action(:create)).post('/mcp', 'HTTPS' => 'on', 'HTTP_HOST' => 'example.com', 'SCRIPT_NAME' => '/backend/app')
    expect(response.status).to eq(401)
    expect(response.headers['www-authenticate']).to eq(
      'Bearer scope="mcp:tools", resource_metadata="https://example.com/backend/app/.well-known/oauth-protected-resource"',
    )
  end

  context 'with a token verifier' do
    let(:verifier) do
      Class.new do
        def verify(token)
          scopes = { 'good' => %w[mcp:tools], 'narrow' => [] }[token]
          MCP::Server::OAuth::AccessToken.new(token:, scopes:, subject: "user-#{token}") if scopes
        end
      end.new
    end
    let(:controller) { stub_const('VerifiedMcpController', Class.new(McpController) { private def mcp_context = { user: mcp_access_token.subject } }) }

    around do |example|
      Rails.configuration.action_model_context.oauth.verifier = verifier
      example.run
    ensure
      Rails.configuration.action_model_context.oauth.verifier = nil
    end

    def call_who_am_i(token)
      env = { 'HTTPS' => 'on', 'HTTP_HOST' => 'example.com', 'SCRIPT_NAME' => '/backend/app', 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }
      env['HTTP_AUTHORIZATION'] = "Bearer #{token}" if token
      body = { jsonrpc: '2.0', id: 1, method: 'tools/call', params: { name: 'who_am_i', arguments: {} } }.to_json
      Rack::MockRequest.new(controller.action(:create)).post('/mcp', env.merge(input: body))
    end

    it 'answers the SDK challenges, naming the document under the prefix of the request' do
      challenges = [ nil, 'bad', 'narrow' ].map { |token| call_who_am_i(token).then { |response| [ response.status, response.headers['www-authenticate'] ] } }
      expect(challenges).to match(
        [
          [ 401, 'Bearer scope="mcp:tools", resource_metadata="https://example.com/backend/app/.well-known/oauth-protected-resource"' ],
          [ 401, start_with('Bearer error="invalid_token"') & end_with('resource_metadata="https://example.com/backend/app/.well-known/oauth-protected-resource"') ],
          [ 403, start_with('Bearer error="insufficient_scope"') ]
        ],
      )
    end

    it 'hands the verified token to mcp_context' do
      response = call_who_am_i('good')
      expect(JSON.parse(response.body).dig('result', 'structuredContent')).to eq('user' => 'user-good')
    end
  end
end
