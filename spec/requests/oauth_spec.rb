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
end
