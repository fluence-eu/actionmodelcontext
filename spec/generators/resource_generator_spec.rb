require "rails_helper"
require "tmpdir"
require "generators/action_model_context/resource/resource_generator"

RSpec.describe ActionModelContext::Generators::ResourceGenerator do
  let(:destination) { Dir.mktmpdir }

  after { FileUtils.remove_entry(destination) }

  def run(*args, framework: "rspec") = described_class.start([ *args, "--test-framework=#{framework}" ], destination_root: destination, debug: true)

  def read(path) = File.read(File.join(destination, path))

  it "derives read params from the URI template" do
    run("User", "--uri", "users://{id}")
    expect(read("app/mcp/resources/user_resource.rb")).to include(
      "class UserResource < ApplicationResource", %(uri "users://{id}"), "def read(id:)",
      %(raise ActionModelContext::Error, "UserResource is not implemented yet")
    )
  end

  it "derives several params in order" do
    run("Comment", "--uri", "posts://{post_id}/comments/{id}")
    expect(read("app/mcp/resources/comment_resource.rb")).to include("def read(post_id:, id:)")
  end

  it "defaults to a static URI" do
    run("Settings")
    expect(read("app/mcp/resources/settings_resource.rb")).to include(%(uri "app://settings"), "def read\n")
  end

  it "generates an RSpec test" do
    run("User", "--uri", "users://{id}")
    expect(read("spec/mcp/resources/user_resource_spec.rb")).to include("RSpec.describe UserResource", "skip")
  end

  it "generates a Minitest test" do
    run("User", framework: "test_unit")
    expect(read("test/mcp/resources/user_resource_test.rb")).to include("class UserResourceTest < ActiveSupport::TestCase", "skip")
  end

  it "produces valid Ruby" do
    run("User", "--uri", "users://{id}")
    run("User", "--uri", "users://{id}", framework: "test_unit")
    files = Dir.glob(File.join(destination, "**/*.rb"))
    expect(files.size).to eq(3)
    files.each { expect(`#{RbConfig.ruby} -c #{_1}`).to include("Syntax OK") }
  end
end
