require 'rails_helper'

RSpec.describe 'MCP endpoint under concurrent requests' do
  def rpc(method, params, headers)
    body = { jsonrpc: '2.0', id: 1, method:, params: }.to_json
    env = { input: body, 'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json' }.merge(headers)
    JSON.parse(Rack::MockRequest.new(Rails.application).post('/mcp', env).body, symbolize_names: true)[:result]
  end

  def call_who_am_i(user) = rpc('tools/call', { name: 'who_am_i', arguments: {} }, 'HTTP_X_USER' => user)[:structuredContent][:user]
  def refund_description(locale) = rpc('tools/list', {}, 'HTTP_ACCEPT_LANGUAGE' => locale)[:tools].find { |tool| tool[:name] == 'billing_refund' }[:description]

  it 'never leaks context or locale between concurrent requests' do
    # Rails 8.0's lazy route set and generate_local_secret race on a cold first request: CI seed 6009 got 404s and an ArgumentError.
    Rails.application.routes.routes
    Rails.application.secret_key_base
    descriptions = { 'en' => 'Refund an invoice', 'fr' => 'Rembourse une facture' }
    threads = Array.new(16) do |i|
      Thread.new do
        user = "u#{i}"
        locale = i.even? ? 'fr' : 'en'
        Array.new(10) { [ user, locale, call_who_am_i(user), refund_description(locale) ] }
      end
    end
    # `value` re-raises the first failed thread at once; without this join its 3 still-running siblings hung the suite at exit.
    threads.each { |thread| thread.join rescue nil }
    expect(threads.flat_map(&:value)).to all(satisfy { |user, locale, seen_user, description| seen_user == user && description == descriptions.fetch(locale) })
  end
end
