require "rails_helper"
require "tmpdir"
require "generators/action_model_context/install/install_generator"

RSpec.describe ActionModelContext::Generators::InstallGenerator do
  let(:destination) { Dir.mktmpdir }

  before do
    FileUtils.mkdir_p(File.join(destination, "config"))
    File.write(File.join(destination, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
    described_class.start([], destination_root: destination)
  end

  after { FileUtils.remove_entry(destination) }

  def read(path) = File.read(File.join(destination, path))

  def generated_files = Dir.glob(File.join(destination, "**/*.rb"))

  it("creates the tool base class") { expect(read("app/mcp/tools/application_tool.rb")).to include("class ApplicationTool < ActionModelContext::Tool") }
  it("creates the resource base class") { expect(read("app/mcp/resources/application_resource.rb")).to include("class ApplicationResource < ActionModelContext::Resource") }
  it("creates the prompt base class") { expect(read("app/mcp/prompts/application_prompt.rb")).to include("class ApplicationPrompt < ActionModelContext::Prompt") }
  it("creates the controller") { expect(read("app/controllers/mcp_controller.rb")).to include("include ActionModelContext::Server", "def mcp_context = {}") }
  it("adds the route") { expect(read("config/routes.rb")).to include("resource :mcp, controller: :mcp, only: %i[show create destroy]") }

  it "produces valid Ruby" do
    generated_files.each { |file| expect(`#{RbConfig.ruby} -c #{file}`).to include("Syntax OK") }
  end
end
