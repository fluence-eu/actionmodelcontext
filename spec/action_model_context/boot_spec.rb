require 'rails_helper'

RSpec.describe 'boot' do
  it 'loads the railtie through the gem name like Bundler does' do
    out = `#{RbConfig.ruby} -Ilib -e 'require "rails"; require "actionmodelcontext"; print defined?(ActionModelContext::Railtie)'`
    expect(out).to eq('constant')
  end

  it 'builds a tool schema without Rails' do
    out = `#{RbConfig.ruby} -Ilib -e 'require "action_model_context"; tool = Class.new(ActionModelContext::Tool) { argument :a, :string }; print [ defined?(Rails), tool.to_mcp(context: nil).to_h[:inputSchema].slice(:type, :properties, :required) ].to_json'`
    expect(out).to eq(%([null,{"type":"object","properties":{"a":{"type":"string"}}}]))
  end

  it 'collapses app/mcp subdirectories' do
    expect(CollapseProbe.name).to eq('CollapseProbe')
    expect(Nested::CollapseProbe.name).to eq('Nested::CollapseProbe')
    expect(defined?(Tools)).to be_nil
  end

  it('keeps the namespace of the other app/mcp directories') { expect(Billing::TaxRate.name).to eq('Billing::TaxRate') }
end
