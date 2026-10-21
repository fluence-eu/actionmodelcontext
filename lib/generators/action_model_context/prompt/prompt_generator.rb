require "rails/generators"
require "generators/action_model_context/argument"

module ActionModelContext
  module Generators
    class PromptGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :specs, type: :array, default: [], banner: "name[:required]"

      def create_prompt_file = template("prompt.rb", File.join("app/mcp/prompts", class_path, "#{file_name}_prompt.rb"))

      hook_for :test_framework, as: :mcp_prompt

      private

      def arguments = @arguments ||= specs.map { Argument.parse(_1, typed: false) }

      def signature = arguments.map(&:keyword).join(", ")
    end
  end
end
