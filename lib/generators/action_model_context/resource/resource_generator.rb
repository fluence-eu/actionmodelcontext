require "rails/generators"
require "action_model_context"

module ActionModelContext
  module Generators
    class ResourceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("templates", __dir__)

      class_option :uri, type: :string, desc: "URI or URI template, e.g. users://{id}"

      def create_resource_file = template("resource.rb", File.join("app/mcp/resources", class_path, "#{file_name}_resource.rb"))

      hook_for :test_framework, as: :mcp_resource

      private

      def uri = options[:uri] || "app://#{file_name}"

      def signature = uri.scan(ActionModelContext::Resource::URI_VARIABLE).flatten.map { "#{_1}:" }.join(", ")
    end
  end
end
