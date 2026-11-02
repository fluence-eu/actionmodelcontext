require 'rails/generators'

# Minitest generators of the tests of the primitives.
#
# @api private
module TestUnit
  module Generators
    # Creates the test of a prompt.
    #
    # @api private
    class McpPromptGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      # Creates the test.
      #
      # @return [void]
      def create_prompt_test = template('prompt_test.rb', File.join('test/mcp/prompts', class_path, "#{file_name}_prompt_test.rb"))
    end
  end
end
