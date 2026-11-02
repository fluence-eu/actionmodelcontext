require 'rails/generators'
require 'generators/action_model_context/argument'

module ActionModelContext
  module Generators
    # Creates a prompt under `app/mcp/prompts`, and its test.
    #
    # @api private
    class PromptGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      argument :specs, type: :array, default: [], banner: 'name[:required]'

      # Creates the prompt.
      #
      # @return [void]
      def create_prompt_file = template('prompt.rb', File.join('app/mcp/prompts', class_path, "#{file_name}_prompt.rb"))

      hook_for :test_framework, as: :mcp_prompt do |generator|
        invoke generator, [ remove_possible_suffix(name), *specs ]
      end

      private

      # Drops the suffix from the file name.
      #
      # @return [String]
      def file_name = @_file_name ||= remove_possible_suffix(super)

      # Drops the `Prompt` suffix from a name.
      #
      # @param name [String] the name
      # @return [String]
      def remove_possible_suffix(name) = name.sub(/_?prompt$/i, '')

      # Parses the arguments of the command line.
      #
      # @return [Array<Argument>]
      def arguments = @arguments ||= specs.map { |spec| Argument.parse(spec, typed: false) }

      # Gives the signature of the generated `call`.
      #
      # @return [String]
      def signature = arguments.map(&:keyword).join(', ')
    end
  end
end
