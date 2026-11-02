require 'active_support/concern'
require 'active_support/rescuable'

module ActionModelContext
  # Shared by {Tool}, {Resource} and {Prompt}: the class macros that name and describe a primitive,
  # and `rescue_from`, which works as in a controller.
  #
  # @api public
  module Primitive
    extend ActiveSupport::Concern

    included do
      include ActiveSupport::Rescuable

      class_attribute :i18n_kind, :name_suffix, instance_accessor: false, instance_predicate: false
    end

    # @!method primitive(kind:, suffix:)
    #   @!scope class
    #   Declares the I18n scope and the class name suffix of a family of primitives.
    #   @param kind [Symbol] the I18n scope
    #   @param suffix [String] the class name suffix to drop from the default name
    #   @return [void]
    #   @api private
    #
    # @!method description(text = nil)
    #   @!scope class
    #   Declares the description, or reads it: a declared value wins over I18n.
    #   @param text [String, nil] the description to declare
    #   @return [String, nil] nil when neither the class nor I18n has one
    #   @api public
    #
    # @!method title(text = nil)
    #   @!scope class
    #   Declares the title, or reads it: a declared value wins over I18n.
    #   @param text [String, nil] the title to declare
    #   @return [String, nil] nil when neither the class nor I18n has one
    #   @api public
    #
    # @!method primitive_name(name = nil)
    #   @!scope class
    #   Declares the name, or reads it.
    #   @param name [String, nil] the name to declare
    #   @return [String, nil] the declared name, else one derived from the class name, nil for an anonymous class
    #   @api private

    class_methods do
      def primitive(kind:, suffix:)
        self.i18n_kind = kind
        self.name_suffix = suffix
      end

      def description(text = nil)
        return @declared_description = text if text

        @declared_description || Translation.lookup(i18n_kind, primitive_name, :description)
      end

      def title(text = nil)
        return @declared_title = text if text

        @declared_title || Translation.lookup(i18n_kind, primitive_name, :title)
      end

      def primitive_name(name = nil)
        return @declared_name = name if name

        @declared_name || Naming.default_name(self, suffix: name_suffix)
      end
    end

    # The context of the request: what the controller's `mcp_context` returned.
    #
    # @return [Object]
    attr_reader :context

    # Creates the primitive for a request.
    #
    # @param context [Object] what the controller's `mcp_context` returned
    # @return [void]
    # @api private
    def initialize(context:)
      @context = context
    end

    private

    # rescue_with_handler returns the exception, not the handler's value, so its walk up the causes is redone here.
    #
    # @yieldreturn [Object] the value of the primitive's method
    # @return [Object] that value, or the return value of the `rescue_from` handler
    # @api private
    def with_rescue
      yield
    rescue StandardError => e
      handled = e
      handled = handled.cause until handled.nil? || (handler = handler_for_rescue(handled))
      handler ? handler.call(handled) : raise
    end

    # Turns an {Error} into an `invalid_params` JSON-RPC error.
    #
    # @param error [Error] the error to report
    # @return [void]
    # @raise [MCP::Server::RequestHandlerError] always
    # @api private
    def raise_invalid_params(error)
      raise MCP::Server::RequestHandlerError.new(
        error.message, nil, error_type: :invalid_params, error_code: JsonRpcHandler::ErrorCode::INVALID_PARAMS,
      )
    end
  end
end
