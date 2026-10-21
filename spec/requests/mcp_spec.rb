require "rails_helper"

RSpec.describe "MCP endpoint", type: :request do
  let(:json_headers) { { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json, text/event-stream" } }

  def post_json(body, headers = {})
    post "/mcp", params: body, headers: json_headers.merge(headers)
    JSON.parse(response.body, symbolize_names: true)
  end

  def request_body(method, params) = { jsonrpc: "2.0", id: 1, method:, params: }
  def tool_names = rpc("tools/list")[:result][:tools].pluck(:name)
  def call_tool(name, headers: {}, **arguments) = rpc("tools/call", { name:, arguments: }, headers)[:result]
  def description_of(name, headers) = rpc("tools/list", {}, headers)[:result][:tools].find { _1[:name] == name }[:description]

  shared_examples "an MCP endpoint" do
    it("lists only concrete tools") { expect(tool_names).to contain_exactly("echo", "who_am_i", "failing", "billing_refund") }
    it("calls a tool through the controller") { expect(call_tool("echo", message: "hi")[:content].first[:text]).to eq("hi") }
    it("passes mcp_context to tools") { expect(call_tool("who_am_i", headers: { "X-User" => "ada" })[:structuredContent]).to eq(user: "ada") }
    it("localizes descriptions per request") { expect(description_of("billing_refund", "Accept-Language" => "fr")).to eq("Rembourse une facture") }

    it "serves resources, resource templates and prompts" do
      expect(rpc("resources/list")[:result][:resources].pluck(:uri)).to eq([ "app://readme" ])
      expect(rpc("resources/templates/list")[:result][:resourceTemplates].pluck(:uriTemplate)).to eq([ "users://{id}" ])
      expect(rpc("prompts/list")[:result][:prompts].pluck(:name)).to eq([ "summarize" ])
    end

    it "passes mcp_context to resources" do
      contents = rpc("resources/read", { uri: "users://42" }, "X-User" => "ada")[:result][:contents]
      expect(JSON.parse(contents.first[:text], symbolize_names: true)).to eq(id: "42", viewer: "ada")
    end
  end

  context "with the legacy lifecycle" do
    let(:initialize_result) do
      handshake = { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "spec", version: "1.0" } }
      post_json(request_body("initialize", handshake).to_json)[:result]
    end

    def rpc(method, params = {}, headers = {})
      post_json(request_body(method, params).to_json, headers.merge("MCP-Protocol-Version" => initialize_result[:protocolVersion]))
    end

    it_behaves_like "an MCP endpoint"

    it("advertises no listChanged nor logging") { expect(initialize_result[:capabilities]).to eq(tools: {}, resources: {}, prompts: {}) }
    it("names the server after the app") { expect(initialize_result[:serverInfo]).to include(name: "dummy") }

    context "with a Rails.error subscriber" do
      let(:subscriber) { Struct.new(:reports) { def report(error, **options) = reports << [ error, options ] }.new([]) }

      before { Rails.error.subscribe(subscriber) }
      after { Rails.error.unsubscribe(subscriber) }

      it "reports internal errors once to Rails.error, not client errors" do
        call_tool("failing")
        call_tool("missing")
        post_json("{")
        expect(subscriber.reports).to contain_exactly([ an_instance_of(RuntimeError), hash_including(handled: true, source: "actionmodelcontext") ])
      end

      it "reports once a token verifier plugged through mcp_transport_options that crashes" do
        controller = stub_const("VerifiedMcpController", Class.new(McpController) do
          private def mcp_transport_options = { token_verifier: Class.new { def verify(_token) = raise("JWKS unreachable") }.new }
        end)
        raw = Rack::MockRequest.new(controller.action(:create)).post(
          "/mcp", input: request_body("tools/list", {}).to_json,
          "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json", "HTTP_AUTHORIZATION" => "Bearer t",
        )
        expect(raw.status).to eq(500)
        expect(subscriber.reports).to contain_exactly([ have_attributes(message: "JWKS unreachable"), anything ])
      end

      it "skips OAuth errors" do
        ActionModelContext::ErrorReporter.call(MCP::Server::OAuth::InsufficientScopeError.new, {})
        expect(subscriber.reports).to be_empty
      end
    end
  end

  context "with the 2026-07-28 lifecycle" do
    def rpc(method, params = {}, headers = {})
      body = MCP::Client::ModernEnvelope.stamp(
        request_body(method, params), protocol_version: "2026-07-28", client_info: { name: "spec", version: "1.0" }, capabilities: {},
      )
      mirrored = { "MCP-Protocol-Version" => "2026-07-28", "Mcp-Method" => method, "Mcp-Name" => params[:name] || params[:uri] }.compact
      post_json(body.to_json, headers.merge(mirrored))
    end

    it_behaves_like "an MCP endpoint"

    it("answers in the 2026-07-28 result shape") { expect(rpc("tools/list")[:result]).to include(resultType: "complete") }
  end

  context "with forgery protection enabled" do
    around do |example|
      enabled = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = enabled
    end

    it "accepts a POST without CSRF token on an ActionController::Base parent" do
      post "/mcp", params: request_body("tools/list", {}).to_json, headers: json_headers
      expect(response).to have_http_status(:ok)
    end
  end

  it "reads a body Rails already consumed from a non-rewindable input" do
    input = StringIO.new(request_body("tools/call", { name: "echo", arguments: { message: "hi" } }).to_json)
    input.singleton_class.undef_method(:rewind)
    raw = Rack::MockRequest.new(Rails.application).post("/mcp", input:, "CONTENT_TYPE" => "application/json", "HTTP_ACCEPT" => "application/json")
    expect(JSON.parse(raw.body, symbolize_names: true).dig(:result, :content, 0, :text)).to eq("hi")
  end

  it "rejects a non-JSON POST with 415" do
    post "/mcp", params: "x", headers: { "CONTENT_TYPE" => "text/plain" }
    expect(response).to have_http_status(415)
  end

  it "answers GET with 405" do
    get "/mcp"
    expect(response).to have_http_status(405)
  end

  it "answers DELETE with 200" do
    delete "/mcp"
    expect(response).to have_http_status(:ok)
  end

  it "discovers nothing on a fresh install and never exposes the base class" do
    stub_const("ApplicationTool", Class.new(ActionModelContext::Tool))
    expect(ActionModelContext::Server.discover("ApplicationTool", "tools_absent")).to eq([])
  end

  it("discovers nothing without a base class") { expect(ActionModelContext::Server.discover("MissingTool", "tools_absent")).to eq([]) }

  it "can be included in an ActionController::API controller" do
    expect { Class.new(ActionController::API) { include ActionModelContext::Server } }.not_to raise_error
  end
end
