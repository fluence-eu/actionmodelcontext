require "rails/generators"
require "generators/action_model_context/argument"

module TestUnit
  module Generators
    class McpToolGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :specs, type: :array, default: [], banner: "name[:type][:required]"

      def create_tool_test = template("tool_test.rb", File.join("test/mcp/tools", class_path, "#{file_name}_tool_test.rb"))

      private

      def placeholders = specs.map { ActionModelContext::Generators::Argument.parse(_1) }.select(&:required).map(&:placeholder).join(", ")
    end
  end
end
