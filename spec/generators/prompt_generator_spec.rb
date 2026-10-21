require "rails_helper"
require "tmpdir"
require "generators/action_model_context/prompt/prompt_generator"

RSpec.describe ActionModelContext::Generators::PromptGenerator do
  let(:destination) { Dir.mktmpdir }

  after { FileUtils.remove_entry(destination) }

  def run(*args, framework: "rspec") = described_class.start([ *args, "--test-framework=#{framework}" ], destination_root: destination, debug: true)

  def read(path) = File.read(File.join(destination, path))

  it "generates the prompt with its arguments" do
    run("Summarize", "topic:required", "tone")
    expect(read("app/mcp/prompts/summarize_prompt.rb")).to include(
      "class SummarizePrompt < ApplicationPrompt", %(description "Summarize"),
      "argument :topic, required: true", "argument :tone\n", "def call(topic:, tone: nil)"
    )
  end

  it "generates an RSpec test" do
    run("Summarize", "topic:required")
    expect(read("spec/mcp/prompts/summarize_prompt_spec.rb")).to include("RSpec.describe SummarizePrompt", "skip")
  end

  it "generates a Minitest test" do
    run("Summarize", "topic:required", framework: "test_unit")
    expect(read("test/mcp/prompts/summarize_prompt_test.rb")).to include("class SummarizePromptTest < ActiveSupport::TestCase", "skip")
  end

  it "produces valid Ruby" do
    run("Summarize", "topic:required")
    run("Summarize", "topic:required", framework: "test_unit")
    files = Dir.glob(File.join(destination, "**/*.rb"))
    expect(files.size).to eq(3)
    files.each { expect(`#{RbConfig.ruby} -c #{_1}`).to include("Syntax OK") }
  end

  it("rejects a type") { expect { run("Summarize", "topic:string") }.to raise_error(Thor::Error) }
end
