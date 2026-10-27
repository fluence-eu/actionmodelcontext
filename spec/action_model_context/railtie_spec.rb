require 'rails_helper'

RSpec.describe ActionModelContext::Railtie do
  let(:middlewares) { [] }
  let(:app) do
    config = ActiveSupport::OrderedOptions.new
    config.action_model_context = ActiveSupport::OrderedOptions.new
    config.action_model_context.oauth = ActiveSupport::OrderedOptions.new
    Struct.new(:config, :middleware).new(config, Struct.new(:entries) { def use(*args) = entries << args }.new(middlewares))
  end
  let(:oauth) { app.config.action_model_context.oauth }

  def run_oauth_initializer = described_class.instance.initializers.find { |initializer| initializer.name == 'action_model_context.oauth' }.run(app)

  it 'builds the document and serves it' do
    oauth.resource = 'https://example.com/mcp'
    oauth.authorization_servers = [ 'https://auth.example.com' ]
    run_oauth_initializer
    expect(middlewares).to eq([ [ ActionModelContext::ProtectedResourceMetadataMiddleware, oauth.metadata ] ])
    expect(oauth.metadata.resource).to eq('https://example.com/mcp')
  end

  it 'publishes nothing without a resource' do
    run_oauth_initializer
    expect([ oauth.metadata, middlewares ]).to eq([ nil, [] ])
  end

  it 'refuses a token_verifier without a resource, which would leave the endpoint open' do
    oauth.token_verifier = ->(_metadata) { :verifier }
    expect { run_oauth_initializer }.to raise_error(ArgumentError, /requires oauth.resource/)
  end

  it 'hands the document to token_verifier when the app prepares' do
    rails_oauth = Rails.application.config.action_model_context.oauth
    rails_oauth.token_verifier = ->(metadata) { "verifier for #{metadata.resource}" }
    described_class.config.to_prepare_blocks.each(&:call)
    expect(rails_oauth.verifier).to eq('verifier for https://example.com/backend/app/mcp')
  ensure
    rails_oauth.token_verifier = rails_oauth.verifier = nil
  end
end
