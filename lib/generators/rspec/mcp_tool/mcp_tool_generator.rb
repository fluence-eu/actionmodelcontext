require "rails/generators"
require "generators/action_model_context/argument"

module Rspec
  module Generators
    class McpToolGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :specs, type: :array, default: [], banner: "name[:type][:required]"

      def create_tool_test = template("tool_spec.rb", File.join("spec/mcp/tools", class_path, "#{file_name}_tool_spec.rb"))

      private

      def placeholders = specs.map { |spec| ActionModelContext::Generators::Argument.parse(spec) }.select(&:required).map(&:placeholder).join(", ")
    end
  end
end
