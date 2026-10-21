require "rails/generators"

module Rspec
  module Generators
    class McpPromptGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      def create_prompt_test = template("prompt_spec.rb", File.join("spec/mcp/prompts", class_path, "#{file_name}_prompt_spec.rb"))
    end
  end
end
