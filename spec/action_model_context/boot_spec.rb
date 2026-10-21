require "rails_helper"

RSpec.describe "boot" do
  it "loads the railtie through the gem name like Bundler does" do
    out = `#{RbConfig.ruby} -Ilib -e 'require "rails"; require "actionmodelcontext"; print defined?(ActionModelContext::Railtie)'`
    expect(out).to eq("constant")
  end

  it "collapses app/mcp subdirectories" do
    expect(CollapseProbe.name).to eq("CollapseProbe")
    expect(Nested::CollapseProbe.name).to eq("Nested::CollapseProbe")
    expect(defined?(Tools)).to be_nil
  end
end
