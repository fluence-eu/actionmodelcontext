require "rails_helper"

RSpec.describe ActionModelContext::Prompt do
  let(:context) { { user: "ada" } }

  after { I18n.backend.reload! }

  let(:prompts) { [ SummarizePrompt ] }
  let(:server) { MCP::Server.new(prompts: prompts.map { |p| p.to_mcp(context:) }) }

  def rpc(method, params = {}) = server.handle({ jsonrpc: "2.0", id: 1, method:, params: })
  def list = rpc("prompts/list")[:result]
  def get(name, **arguments) = rpc("prompts/get", { name:, arguments: })

  def prompt_class(name, &body) = stub_const(name, Class.new(described_class, &body))

  it("derives the name") { expect(SummarizePrompt.prompt_name).to eq("summarize") }
  it("lists arguments") { expect(list[:prompts].first[:arguments]).to eq([ { name: "topic", required: true } ]) }

  it "turns a String into one user message" do
    expect(get("summarize", topic: "Rails")[:result][:messages]).to eq(
      [ { role: "user", content: { type: "text", text: "Summarize Rails in three points" } } ],
    )
  end

  context "with a prompt returning an Array" do
    let(:prompts) { [ prompt_class("ChatPrompt") { def call = [ { role: "assistant", content: "ok" } ] } ] }

    it "turns it into messages" do
      expect(get("chat")[:result][:messages]).to eq([ { role: "assistant", content: { type: "text", text: "ok" } } ])
    end
  end

  context "with a prompt raising ActionModelContext::Error" do
    let(:prompts) do
      [ prompt_class("StrictPrompt") do
        argument :topic
        def call(topic: nil) = raise(ActionModelContext::Error, "Bad topic")
      end ]
    end

    it "surfaces it as a JSON-RPC error with its message" do
      expect(get("strict")[:error]).to include(code: -32_602, message: "Bad topic")
    end
  end

  context "with a prompt returning a malformed Array" do
    let(:reported) { [] }
    let(:prompts) { [ prompt_class("MalformedPrompt") { def call = [ { "role" => "user", "content" => "x" } ] } ] }
    let(:server) do
      sink = reported
      MCP::Server.new(
        prompts: prompts.map { |p| p.to_mcp(context:) },
        configuration: MCP::Configuration.new(exception_reporter: ->(e, _) { sink << e }),
      )
    end

    it "masks the failure as an internal error and reports a KeyError" do
      expect(get("malformed")[:error]).to include(code: -32_603)
      expect(reported.first).to be_a(KeyError)
    end
  end

  it "rejects other return types" do
    prompt = prompt_class("BadPrompt") { def call = 42 }
    expect { prompt.new(context:).call_mcp({}) }.to raise_error(TypeError, /String or Array/)
  end

  it "is concrete once a subclass defines call" do
    base = Class.new(described_class)
    expect([ described_class, base, Class.new(base) { def call = "ok" } ].map(&:concrete?)).to eq([ false, false, true ])
  end

  it "passes only declared arguments" do
    prompt = prompt_class("PickyPrompt") do
      argument :topic
      def call(topic: nil) = topic.to_s
    end
    result = prompt.new(context:).call_mcp({ topic: "a", extra: "b" })
    expect(result.messages.first.content.text).to eq("a")
  end

  it "takes argument descriptions from I18n" do
    I18n.backend.store_translations(:en, action_model_context: { prompts: { summarize: { arguments: { topic: "What to cover" } } } })
    expect(list[:prompts].first[:arguments]).to eq([ { name: "topic", description: "What to cover", required: true } ])
  end

  it "takes title and description from I18n" do
    I18n.backend.store_translations(:en, action_model_context: { prompts: { summarize: { title: "Summarize", description: "Sums up" } } })
    expect(list[:prompts]).to include(hash_including(name: "summarize", title: "Summarize", description: "Sums up"))
  end

  it "applies rescue_from handlers" do
    prompt = prompt_class("GuardedPrompt") do
      rescue_from(KeyError) { raise ActionModelContext::Error, "Nope" }
      def call = context.fetch(:missing)
    end
    expect { prompt.new(context:).call_mcp({}) }.to raise_error(MCP::Server::RequestHandlerError, "Nope")
  end

  context "with a Hash context and request _meta" do
    let(:seen) { [] }
    let(:prompts) do
      captured = seen
      [ prompt_class("SeenPrompt") { define_method(:call) { captured << context && "ok" } } ]
    end

    it "gives the prompt the exact context object, not the SDK copy" do
      rpc("prompts/get", { name: "seen", _meta: { progressToken: "t" } })
      expect(seen.first).to equal(context)
    end
  end
end
