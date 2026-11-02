require 'rails/generators'

module TestUnit
  module Generators
    # Creates the test of a resource.
    #
    # @api private
    class McpResourceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      # Creates the test.
      #
      # @return [void]
      def create_resource_test = template('resource_test.rb', File.join('test/mcp/resources', class_path, "#{file_name}_resource_test.rb"))
    end
  end
end
