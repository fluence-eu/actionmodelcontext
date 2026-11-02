require 'rails/generators'
require 'action_model_context'

module ActionModelContext
  module Generators
    # Creates a resource under `app/mcp/resources`, and its test.
    #
    # @api private
    class ResourceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      class_option :uri, type: :string, desc: 'URI or URI template, e.g. users://{id}'

      # Creates the resource.
      #
      # @return [void]
      def create_resource_file = template('resource.rb', File.join('app/mcp/resources', class_path, "#{file_name}_resource.rb"))

      hook_for :test_framework, as: :mcp_resource do |generator|
        invoke generator, [ remove_possible_suffix(name) ]
      end

      private

      # Drops the suffix from the file name.
      #
      # @return [String]
      def file_name = @_file_name ||= remove_possible_suffix(super)

      # Drops the `Resource` suffix from a name.
      #
      # @param name [String] the name
      # @return [String]
      def remove_possible_suffix(name) = name.sub(/_?resource$/i, '')

      # Gives the URI of the generated resource.
      #
      # @return [String]
      def uri = options[:uri] || "app://#{file_name}"

      # Gives the signature of the generated `read`.
      #
      # @return [String]
      def signature = uri.scan(ActionModelContext::Resource::URI_VARIABLE).flatten.map { |variable| "#{variable}:" }.join(', ')
    end
  end
end
