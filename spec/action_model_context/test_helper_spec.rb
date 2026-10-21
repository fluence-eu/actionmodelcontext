require "rails_helper"
require "action_model_context/test_helper"

RSpec.describe ActionModelContext::TestHelper do
  include ActionModelContext::TestHelper

  it("returns text") { expect(call_tool(EchoTool, message: "hi").text).to eq("hi") }
  it("returns structured content") { expect(call_tool(WhoAmITool, context: { user: "ada" }).structured_content).to eq(user: "ada") }
  it("returns no structured content for a String") { expect(call_tool(EchoTool, message: "hi").structured_content).to be_nil }
  it("is not an error on success") { expect(call_tool(EchoTool, message: "hi").error?).to be(false) }
  it("flags missing required arguments") { expect(call_tool(EchoTool).error?).to be(true) }
  it("flags schema violations") { expect(call_tool(EchoTool, message: "hi", times: "x").error?).to be(true) }
  it("flags ActionModelContext::Error with its message") do
    result = call_tool(WhoAmITool)
    expect([ result.error?, result.text ]).to eq([ true, "Unknown user" ])
  end
  it("re-raises the original exception") { expect { call_tool(FailingTool) }.to raise_error(RuntimeError, "secret internals") }
  it("keeps the original backtrace") do
    expect { call_tool(FailingTool) }.to raise_error { |e| expect(e.backtrace.first).to include("failing_tool.rb") }
  end
  it("does not report through the global reporter") do
    allow(Rails.error).to receive(:report)
    expect { call_tool(FailingTool) }.to raise_error(RuntimeError)
    expect(Rails.error).not_to have_received(:report)
  end
end
