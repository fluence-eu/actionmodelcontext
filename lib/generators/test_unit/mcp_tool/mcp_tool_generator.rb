require 'rails/generators'
require 'generators/action_model_context/argument'

module TestUnit
  module Generators
    # Creates the test of a tool.
    #
    # @api private
    class McpToolGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      argument :specs, type: :array, default: [], banner: 'name[:type][:required]'

      # Creates the test.
      #
      # @return [void]
      def create_tool_test = template('tool_test.rb', File.join('test/mcp/tools', class_path, "#{file_name}_tool_test.rb"))

      private

      # Gives the required arguments with example values.
      #
      # @return [String]
      def placeholders = specs.map { |spec| ActionModelContext::Generators::Argument.parse(spec) }.select(&:required).map(&:placeholder).join(', ')
    end
  end
end
