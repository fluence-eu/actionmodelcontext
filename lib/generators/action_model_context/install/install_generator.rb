require 'rails/generators'

module ActionModelContext
  module Generators
    # Creates the base classes, the controller and the route.
    #
    # @api private
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      # Creates `ApplicationTool`, `ApplicationResource` and `ApplicationPrompt`.
      #
      # @return [void]
      def create_base_classes
        template 'application_tool.rb', 'app/mcp/tools/application_tool.rb'
        template 'application_resource.rb', 'app/mcp/resources/application_resource.rb'
        template 'application_prompt.rb', 'app/mcp/prompts/application_prompt.rb'
      end

      # Creates `McpController`.
      #
      # @return [void]
      def create_controller = template('mcp_controller.rb', 'app/controllers/mcp_controller.rb')

      # Adds the route of the controller.
      #
      # @return [void]
      def add_route = route('resource :mcp, controller: :mcp, only: %i[show create destroy]')
    end
  end
end
