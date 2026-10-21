require "rails_helper"

RSpec.describe "MCP endpoint reloading", type: :request do
  let(:path) { Rails.root.join("app/mcp/tools/late_tool.rb") }

  after do
    FileUtils.rm_f(path)
    Rails.application.reloader.reload!
  end

  def tool_names
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json, headers: { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" }
    JSON.parse(response.body, symbolize_names: true)[:result][:tools].pluck(:name)
  end

  it "picks up a new tool and forgets a deleted one without restart" do
    path.write(%(class LateTool < ApplicationTool\n  def call = "late"\nend\n))
    Rails.application.reloader.reload!
    expect(tool_names).to include("late")
    path.delete
    Rails.application.reloader.reload!
    expect(tool_names).not_to include("late")
  end
end
