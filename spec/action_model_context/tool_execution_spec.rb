require "rails_helper"

RSpec.describe ActionModelContext::Tool, "execution" do
  let(:reported) { [] }
  let(:context) { { user: "ada" } }
  let(:arguments) { {} }
  let(:tool_class) { EchoTool }
  let(:response) { call(**arguments) }
  let(:result) { response[:result] }

  def call(**args)
    server = MCP::Server.new(
      tools: [ tool_class.to_mcp(context:) ],
      configuration: MCP::Configuration.new(exception_reporter: ->(e, _) { reported << e }),
    )
    server.handle({ jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: tool_class.tool_name, arguments: args } })
  end

  it "returns text for a String" do
    expect(call(message: "hi", times: 2)[:result][:content]).to eq([ { type: "text", text: "hihi" } ])
  end

  it "ignores arguments outside the schema" do
    expect(call(message: "hi", bogus: 1)[:result][:content].first[:text]).to eq("hi")
  end

  it "lets call defaults apply when an optional argument is absent" do
    expect(call(message: "hi")[:result][:content].first[:text]).to eq("hi")
  end

  context "with a Hash result" do
    let(:tool_class) { WhoAmITool }

    it "fills structuredContent and JSON text" do
      expect(result[:structuredContent]).to eq(user: "ada")
      expect(JSON.parse(result[:content].first[:text])).to eq("user" => "ada")
    end
  end

  context "with an Array result" do
    let(:tool_class) { stub_const("ListTool", Class.new(ApplicationTool) { def call = [ 1, 2 ] }) }

    it "returns JSON text only" do
      expect(result).not_to have_key(:structuredContent)
      expect(result[:content]).to eq([ { type: "text", text: "[1,2]" } ])
    end
  end

  context "with a Response result" do
    let(:tool_class) do
      stub_const("RawTool", Class.new(ApplicationTool) { def call = MCP::Tool::Response.new([ { type: "text", text: "raw" } ]) })
    end

    it("passes it through") { expect(result[:content]).to eq([ { type: "text", text: "raw" } ]) }
  end

  context "when rescue_from maps to ActionModelContext::Error" do
    let(:tool_class) { WhoAmITool }
    let(:context) { {} }

    it "returns isError with the message" do
      expect(result).to include(isError: true, content: [ { type: "text", text: "Unknown user" } ])
    end
  end

  context "when call raises ActionModelContext::Error directly" do
    let(:tool_class) do
      stub_const("DeniedTool", Class.new(ApplicationTool) { def call = raise(ActionModelContext::Error, "Denied") })
    end

    it "returns isError with the message" do
      expect(result).to include(isError: true, content: [ { type: "text", text: "Denied" } ])
    end
  end

  context "when call raises another exception" do
    let(:tool_class) { FailingTool }

    it "masks it as a JSON-RPC internal error" do
      expect(response[:error][:message]).not_to include("secret internals")
    end
  end

  context "with an unsupported return type" do
    let(:tool_class) { stub_const("BadTool", Class.new(ApplicationTool) { def call = Object.new }) }

    it "reports a TypeError" do
      response
      expect(reported.first).to be_a(TypeError).and have_attributes(message: /BadTool#call must return/)
    end
  end

  it "raises NotImplementedError from the base call" do
    expect { described_class.new(context:).call }.to raise_error(NotImplementedError)
  end
end
