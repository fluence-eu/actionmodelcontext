require 'rails_helper'
require 'rack/mock'

RSpec.describe ActionModelContext::ProtectedResourceMetadataMiddleware do
  let(:metadata) do
    MCP::Server::OAuth::ProtectedResourceMetadata.new(resource: 'https://example.com/backend/app/mcp', authorization_servers: [ 'https://auth.example.com' ])
  end
  let(:downstream) { Struct.new(:envs) { def call(env) = (envs << env) && [ 200, {}, [ 'app' ] ] }.new([]) }
  let(:middleware) { described_class.new(downstream, metadata) }

  def env_for(path, method: 'GET', script_name: '/backend/app') = Rack::MockRequest.env_for(path, method:, 'SCRIPT_NAME' => script_name)

  it 'serves the SDK document under the prefix the app is mounted at' do
    status, headers, body = middleware.call(env_for('/.well-known/oauth-protected-resource'))
    expect([ status, headers['access-control-allow-origin'], headers['cache-control'] ]).to eq([ 200, '*', 'public, max-age=3600' ])
    expect(JSON.parse(body.join)).to include('resource' => 'https://example.com/backend/app/mcp', 'authorization_servers' => [ 'https://auth.example.com' ])
  end

  it 'answers preflights and refuses other methods as the SDK does' do
    statuses = %w[OPTIONS POST].map { |method| middleware.call(env_for('/.well-known/oauth-protected-resource', method:)).first }
    expect(statuses).to eq([ 204, 405 ])
  end

  it 'keeps serving the standard RFC 9728 path' do
    expect(middleware.call(env_for('/.well-known/oauth-protected-resource/backend/app/mcp', script_name: '')).first).to eq(200)
  end

  it 'neither hands the document request down nor rewrites the env it was given' do
    env = env_for('/.well-known/oauth-protected-resource')
    middleware.call(env)
    expect([ downstream.envs, env['PATH_INFO'] ]).to eq([ [], '/.well-known/oauth-protected-resource' ])
  end

  it 'passes every other request down untouched' do
    env = env_for('/mcp')
    middleware.call(env)
    expect(downstream.envs).to contain_exactly(be(env))
  end
end
