require 'rails/generators'

module Rspec
  module Generators
    # Creates the spec of a resource.
    #
    # @api private
    class McpResourceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      # Creates the spec.
      #
      # @return [void]
      def create_resource_test = template('resource_spec.rb', File.join('spec/mcp/resources', class_path, "#{file_name}_resource_spec.rb"))
    end
  end
end
