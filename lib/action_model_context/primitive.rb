require "active_support/concern"
require "active_support/rescuable"

module ActionModelContext
  module Primitive
    extend ActiveSupport::Concern

    included do
      include ActiveSupport::Rescuable

      class_attribute :i18n_kind, :name_suffix, instance_accessor: false, instance_predicate: false
    end

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

    attr_reader :context

    def initialize(context:)
      @context = context
    end

    private

    # rescue_with_handler returns the exception, not the handler's value, so its walk up the causes is redone here.
    def with_rescue
      yield
    rescue StandardError => e
      handled = e
      handled = handled.cause until handled.nil? || (handler = handler_for_rescue(handled))
      handler ? handler.call(handled) : raise
    end

    def raise_invalid_params(error)
      raise MCP::Server::RequestHandlerError.new(
        error.message, nil, error_type: :invalid_params, error_code: JsonRpcHandler::ErrorCode::INVALID_PARAMS,
      )
    end
  end
end
