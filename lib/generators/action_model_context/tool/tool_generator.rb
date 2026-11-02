require 'rails/generators'
require 'generators/action_model_context/argument'

module ActionModelContext
  module Generators
    # Creates a tool under `app/mcp/tools`, and its test.
    #
    # @api private
    class ToolGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      argument :specs, type: :array, default: [], banner: 'name:type[:required]'

      # Creates the tool.
      #
      # @return [void]
      def create_tool_file = template('tool.rb', File.join('app/mcp/tools', class_path, "#{file_name}_tool.rb"))

      hook_for :test_framework, as: :mcp_tool do |generator|
        invoke generator, [ remove_possible_suffix(name), *specs ]
      end

      private

      # Drops the suffix from the file name.
      #
      # @return [String]
      def file_name = @_file_name ||= remove_possible_suffix(super)

      # Drops the `Tool` suffix from a name.
      #
      # @param name [String] the name
      # @return [String]
      def remove_possible_suffix(name) = name.sub(/_?tool$/i, '')

      # Parses the arguments of the command line.
      #
      # @return [Array<Argument>]
      def arguments = @arguments ||= specs.map { |spec| Argument.parse(spec) }

      # Gives the signature of the generated `call`.
      #
      # @return [String]
      def signature = arguments.map(&:keyword).join(', ')
    end
  end
end
