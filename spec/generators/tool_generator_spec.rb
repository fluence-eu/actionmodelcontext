require "rails_helper"
require "tmpdir"
require "generators/action_model_context/tool/tool_generator"

RSpec.describe ActionModelContext::Generators::ToolGenerator do
  let(:destination) { Dir.mktmpdir }
  let(:framework) { "rspec" }

  after { FileUtils.remove_entry(destination) }

  def run(*args) = described_class.start([ *args, "--test-framework=#{framework}" ], destination_root: destination, debug: true)

  def read(path) = File.read(File.join(destination, path))

  def exist?(path) = File.exist?(File.join(destination, path))

  context "with typed arguments" do
    before { run("FindUser", "email:string:required", "limit:integer") }

    it "generates the tool" do
      expect(read("app/mcp/tools/find_user_tool.rb")).to include(
        "class FindUserTool < ApplicationTool", %(description "Find user"),
        "argument :email, :string, required: true", "argument :limit, :integer", "def call(email:, limit: nil)"
      )
    end

    it "generates an RSpec test calling the tool with placeholders" do
      expect(read("spec/mcp/tools/find_user_tool_spec.rb")).to include(
        "RSpec.describe FindUserTool", "include ActionModelContext::TestHelper",
        %(call_tool(FindUserTool, email: "example")), "skip"
      )
    end

    it "produces valid Ruby" do
      files = Dir.glob(File.join(destination, "**/*.rb"))
      expect(files).not_to be_empty
      files.each { expect(`#{RbConfig.ruby} -c #{_1}`).to include("Syntax OK") }
    end
  end

  context "with Minitest" do
    let(:framework) { "test_unit" }

    before { run("FindUser", "email:string:required") }

    it "generates a Minitest test" do
      expect(read("test/mcp/tools/find_user_tool_test.rb")).to include(
        "class FindUserToolTest < ActiveSupport::TestCase", "include ActionModelContext::TestHelper",
        %(call_tool(FindUserTool, email: "example")), "skip"
      )
    end

    it "does not generate an RSpec test" do
      expect(exist?("spec/mcp/tools/find_user_tool_spec.rb")).to be(false)
    end

    it "produces valid Ruby" do
      expect(`#{RbConfig.ruby} -c #{File.join(destination, 'test/mcp/tools/find_user_tool_test.rb')}`).to include("Syntax OK")
    end
  end

  it "maps every supported type" do
    run("Kitchen", "a:text", "b:float", "c:decimal", "d:number", "e:boolean", "f:array", "g:object", "h")
    expect(read("app/mcp/tools/kitchen_tool.rb")).to include(
      "argument :a, :string", "argument :b, :number", "argument :c, :number", "argument :d, :number",
      "argument :e, :boolean", "argument :f, :array", "argument :g, :object", "argument :h, :string",
      "def call(a: nil, b: nil, c: nil, d: nil, e: nil, f: nil, g: nil, h: nil)"
    )
  end

  it "generates a tool without arguments" do
    run("Ping")
    expect(read("app/mcp/tools/ping_tool.rb")).to include("def call\n")
    expect(read("spec/mcp/tools/ping_tool_spec.rb")).to include("call_tool(PingTool)")
  end

  it "generates a call that raises ActionModelContext::Error until implemented" do
    run("Ping")
    path = File.join(destination, "app/mcp/tools/ping_tool.rb")
    sandbox = Module.new { const_set(:ApplicationTool, Class.new(ActionModelContext::Tool)) }
    sandbox.module_eval(File.read(path), path, 1)
    expect { sandbox::PingTool.new(context: {}).call }.to raise_error(ActionModelContext::Error, "PingTool is not implemented yet")
  end

  it "nests namespaced tools" do
    run("Admin::FindUser")
    expect(read("app/mcp/tools/admin/find_user_tool.rb")).to include("class Admin::FindUserTool < ApplicationTool")
    expect(exist?("spec/mcp/tools/admin/find_user_tool_spec.rb")).to be(true)
  end

  it("rejects an unknown type") { expect { run("FindUser", "x:date") }.to raise_error(Thor::Error, /date/) }
  it("rejects too many segments") { expect { run("FindUser", "x:string:required:more") }.to raise_error(Thor::Error) }
end
