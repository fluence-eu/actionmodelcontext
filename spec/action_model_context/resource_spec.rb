require "rails_helper"

RSpec.describe ActionModelContext::Resource do
  let(:context) { { user: "ada" } }

  after { I18n.backend.reload! }

  let(:statics) { [ ReadmeResource ] }
  let(:templates) { [ UserResource ] }
  let(:server) do
    MCP::Server.new(
      resources: statics.reject(&:template?).map { |r| r.to_mcp(context:) },
      resource_templates: templates.select(&:template?).map { |r| r.to_mcp(context:) },
    )
  end

  def rpc(method, params = {}) = server.handle({ jsonrpc: "2.0", id: 1, method:, params: })
  def list = rpc("resources/list")[:result]
  def listed_templates = rpc("resources/templates/list")[:result]
  def read(uri, **extra) = rpc("resources/read", { uri:, **extra })

  it("derives the name") { expect(ReadmeResource.resource_name).to eq("readme") }
  it("detects templates") { expect([ ReadmeResource.template?, UserResource.template? ]).to eq([ false, true ]) }
  it("lists a static resource") { expect(list[:resources]).to include(hash_including(uri: "app://readme", name: "readme")) }
  it("lists a template") { expect(listed_templates[:resourceTemplates]).to include(hash_including(uriTemplate: "users://{id}")) }

  it "reads a String as text/plain" do
    expect(read("app://readme")[:result][:contents]).to eq([ { uri: "app://readme", mimeType: "text/plain", text: "Hello" } ])
  end

  it "reads a template with its params, the context and the concrete URI" do
    expect(read("users://42")[:result][:contents]).to eq(
      [ { uri: "users://42", mimeType: "application/json", text: { id: "42", viewer: "ada" }.to_json } ],
    )
  end

  it "surfaces ActionModelContext::Error as a JSON-RPC error with its message" do
    expect(read("users://0")[:error]).to include(code: -32_602, message: "Unknown user")
  end

  it "lets a declared mime_type win" do
    resource = stub_const("NoteResource", Class.new(described_class) do
      uri "app://note"
      mime_type "text/markdown"
      def read = { a: 1 }
    end)
    expect(resource.new(context:).read_mcp({}).mime_type).to eq("text/markdown")
  end

  it "rejects other return types" do
    resource = stub_const("BadResource", Class.new(described_class) do
      uri "app://bad"
      def read = 42
    end)
    expect { resource.new(context:).read_mcp({}) }.to raise_error(TypeError, /String, Hash or Array/)
  end

  context "with a Hash context and request _meta" do
    let(:seen) { [] }
    let(:statics) do
      captured = seen
      [ stub_const("SeenResource", Class.new(described_class) do
        uri "app://seen"
        define_method(:read) { captured << context && "ok" }
      end) ]
    end
    let(:templates) do
      captured = seen
      [ stub_const("SeenTemplateResource", Class.new(described_class) do
        uri "seen://{id}"
        define_method(:read) { |id:| captured << context && id }
      end) ]
    end

    it "gives a static resource the exact context object, not the SDK copy" do
      read("app://seen", _meta: { progressToken: "t" })
      expect(seen.first).to equal(context)
    end

    it "gives a template the exact context object, not the SDK copy" do
      read("seen://1", _meta: { progressToken: "t" })
      expect(seen.first).to equal(context)
    end
  end

  it "takes title and description from I18n" do
    I18n.backend.store_translations(:en, action_model_context: { resources: { readme: { title: "Readme", description: "The readme" } } })
    expect(list[:resources]).to include(hash_including(name: "readme", title: "Readme", description: "The readme"))
  end

  it "applies rescue_from handlers" do
    resource = stub_const("GuardedResource", Class.new(described_class) do
      uri "app://guarded"
      rescue_from(KeyError) { raise ActionModelContext::Error, "Nope" }
      def read = context.fetch(:missing)
    end)
    expect { resource.new(context:).read_mcp({}) }.to raise_error(MCP::Server::RequestHandlerError, "Nope")
  end
end
