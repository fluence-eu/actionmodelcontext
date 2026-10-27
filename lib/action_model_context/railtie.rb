module ActionModelContext
  class Railtie < Rails::Railtie
    initializer 'action_model_context.autoload' do |app|
      Rails.autoloaders.main.collapse(app.root.join('app/mcp/*').to_s)
    end

    initializer 'action_model_context.exception_reporter' do
      MCP.configure { |config| config.exception_reporter = ErrorReporter }
    end
  end
end
