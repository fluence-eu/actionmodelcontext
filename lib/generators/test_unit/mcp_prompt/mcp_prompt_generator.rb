require "rails/generators"

module TestUnit
  module Generators
    class McpPromptGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      def create_prompt_test = template("prompt_test.rb", File.join("test/mcp/prompts", class_path, "#{file_name}_prompt_test.rb"))
    end
  end
end
