require_relative "boot"
require "rails"
require "action_controller/railtie"

Bundler.require(:default)

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.root = File.expand_path("..", __dir__)
  end
end
