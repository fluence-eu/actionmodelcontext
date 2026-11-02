require 'rails/generators'

# RSpec generators of the specs of the primitives.
#
# @api private
module Rspec
  module Generators
    # Creates the spec of a prompt.
    #
    # @api private
    class McpPromptGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      # Creates the spec.
      #
      # @return [void]
      def create_prompt_test = template('prompt_spec.rb', File.join('spec/mcp/prompts', class_path, "#{file_name}_prompt_spec.rb"))
    end
  end
end
