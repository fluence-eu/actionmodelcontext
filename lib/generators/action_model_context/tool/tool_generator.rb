require "rails/generators"
require "generators/action_model_context/argument"

module ActionModelContext
  module Generators
    class ToolGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      argument :specs, type: :array, default: [], banner: "name:type[:required]"

      def create_tool_file = template("tool.rb", File.join("app/mcp/tools", class_path, "#{file_name}_tool.rb"))

      hook_for :test_framework, as: :mcp_tool do |generator|
        invoke generator, [ remove_possible_suffix(name), *specs ]
      end

      private

      def file_name = @_file_name ||= remove_possible_suffix(super)

      def remove_possible_suffix(name) = name.sub(/_?tool$/i, "")

      def arguments = @arguments ||= specs.map { Argument.parse(_1) }

      def signature = arguments.map(&:keyword).join(", ")
    end
  end
end
