require "rails_helper"

RSpec.describe ActionModelContext::Tool do
  def schema_of(tool) = tool.to_mcp(context: nil).to_h

  let(:refund) do
    stub_const("Billing::RefundTool", Class.new(described_class) { argument :amount, :integer, required: true })
  end

  it("derives the name") { expect(stub_const("FindUserTool", Class.new(described_class)).tool_name).to eq("find_user") }
  it("joins namespaces") { expect(refund.tool_name).to eq("billing_refund") }

  it "lets tool_name override the default" do
    tool = stub_const("FindUserTool", Class.new(described_class) { tool_name "lookup" })
    expect(schema_of(tool)[:name]).to eq("lookup")
  end

  it "builds the input schema from arguments" do
    tool = stub_const("FindUserTool", Class.new(described_class) do
      argument :email, :string, required: true, description: "Exact email"
      argument :tags, :array, items: { type: "string" }
      argument :role, :string, enum: %w[admin member]
    end)
    schema = schema_of(tool)
    expect(schema[:inputSchema][:properties]).to eq(
      email: { type: "string", description: "Exact email" },
      tags: { type: "array", items: { type: "string" } },
      role: { type: "string", enum: %w[admin member] },
    )
    expect(schema[:inputSchema][:required]).to eq([ "email" ])
  end

  it "supports object properties" do
    tool = stub_const("FindUserTool", Class.new(described_class) { argument :filter, :object, properties: { id: { type: "integer" } } })
    expect(schema_of(tool)[:inputSchema][:properties][:filter]).to eq(type: "object", properties: { id: { type: "integer" } })
  end

  it("rejects unknown types") { expect { Class.new(described_class).argument(:x, :date) }.to raise_error(ArgumentError) }

  it "does not leak child arguments to the parent" do
    parent = Class.new(described_class) { argument :a, :string }
    child = Class.new(parent) { argument :b, :string }
    expect([ parent.argument_names, child.argument_names ]).to eq([ [ :a ], %i[a b] ])
  end

  it "emits annotations" do
    tool = stub_const("FindUserTool", Class.new(described_class) { annotations read_only_hint: true })
    expect(schema_of(tool)[:annotations]).to include(readOnlyHint: true)
  end

  it "reads the description from I18n in the current locale" do
    I18n.with_locale(:fr) { expect(schema_of(refund)[:description]).to eq("Rembourse une facture") }
  end

  it "reads argument descriptions from I18n" do
    expect(schema_of(refund)[:inputSchema][:properties][:amount][:description]).to eq("Amount in cents")
  end

  it "follows Rails fallbacks" do
    I18n.with_locale(:fr) { expect(schema_of(refund)[:inputSchema][:properties][:amount][:description]).to eq("Amount in cents") }
  end

  it "prefers the declared value over I18n" do
    refund.description("Explicit")
    refund.title("Explicit title")
    I18n.with_locale(:fr) { expect(schema_of(refund)).to include(description: "Explicit", title: "Explicit title") }
  end

  it "resolves I18n per call, not at class load" do
    expect([ "en", "fr" ].map { |l| I18n.with_locale(l) { schema_of(refund)[:description] } }).to eq([ "Refund an invoice", "Rembourse une facture" ])
  end

  it "omits a missing translation" do
    tool = stub_const("Nothing::HereTool", Class.new(described_class))
    expect(schema_of(tool)).not_to include(:description, :title)
  end

  it "omits translation lookup for anonymous classes" do
    expect(schema_of(Class.new(described_class))).not_to have_key(:description)
  end
end
