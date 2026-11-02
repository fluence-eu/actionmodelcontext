require 'active_support/core_ext/class/attribute'

module ActionModelContext
  # Base class of the resources. An application subclasses it through `ApplicationResource`, under `app/mcp/resources`.
  #
  # @example
  #   class UserResource < ApplicationResource
  #     uri 'users://{id}'
  #
  #     def read(id:) = { id:, viewer: context[:user] }
  #   end
  #
  # @api public
  class Resource
    include Primitive

    primitive kind: :resources, suffix: 'Resource'

    # @api private
    URI_VARIABLE = /\{([A-Za-z_]\w*)\}/

    class_attribute :declared_mime_type, instance_accessor: false, instance_predicate: false

    class << self
      # Declares the URI, or reads it. A `{variable}` makes the resource a template, and subclasses do not inherit it.
      #
      # @param value [String, nil] the URI to declare
      # @return [String, nil] nil when the class declares none
      def uri(value = nil)
        return @declared_uri = value if value

        @declared_uri
      end

      # Declares the MIME type, or reads it. Subclasses inherit it, and it overrides the one derived from {#read}.
      #
      # @param value [String, nil] the MIME type to declare
      # @return [String, nil] nil when none is declared
      def mime_type(value = nil)
        return self.declared_mime_type = value if value

        declared_mime_type
      end

      # Declares the name, or reads it.
      #
      # @param name [String, nil] the name to declare
      # @return [String, nil] the declared name, else the underscored class name without its `Resource` suffix
      def resource_name(name = nil) = primitive_name(name)

      # Tells whether the resource is exposed, which takes its own {uri} and a `read` below this class.
      #
      # @return [Boolean]
      # @api private
      def concrete? = !uri.nil? && instance_method(:read).owner != Resource

      # Tells whether the URI holds variables.
      #
      # @return [Boolean]
      # @api private
      def template? = uri.include?('{')

      # Lists the variables of the URI.
      #
      # @return [Array<Symbol>]
      # @api private
      def uri_variables = uri.scan(URI_VARIABLE).flatten.map(&:to_sym)

      # Builds the SDK resource or resource template for a request.
      #
      # @param context [Object] the context of the request
      # @return [Class<MCP::Resource>, Class<MCP::ResourceTemplate>]
      # @api private
      def to_mcp(context:)
        resource = self
        if template?
          MCP::ResourceTemplate.define(uri_template: uri, **definition) do |**params|
            resource.new(context:).read_mcp(params.except(:server_context))
          end
        else
          MCP::Resource.define(uri:, **definition) { |**| resource.new(context:).read_mcp({}) }
        end
      end

      private

      # Lists the fields common to a resource and a resource template.
      #
      # @return [Hash]
      # @api private
      def definition = { name: resource_name, title:, description:, mime_type: }
    end

    # Reads the resource. A subclass defines it, with one keyword per variable of the URI.
    #
    # @return [String, Hash, Array] the contents: a `String` goes out as `text/plain`, the others as `application/json`
    # @raise [Error] to answer an `invalid_params` JSON-RPC error
    # @raise [NotImplementedError] when no subclass defines it
    def read(**) = raise(NotImplementedError, "#{self.class.name}#read is not implemented")

    # Reads the resource for the SDK.
    #
    # @param params [Hash] the variables of the requested URI
    # @return [MCP::Resource::TextContents]
    # @raise [MCP::Server::RequestHandlerError] when the resource raises {Error}
    # @api private
    def read_mcp(params)
      params = params.slice(*self.class.uri_variables)
      to_contents(with_rescue { read(**params) }, params)
    rescue Error => e
      raise_invalid_params(e)
    end

    private

    # Converts the value of {#read}.
    #
    # @param result [String, Hash, Array] that value
    # @param params [Hash] the variables that expand the URI
    # @return [MCP::Resource::TextContents]
    # @raise [TypeError] when the value is of another class
    # @api private
    def to_contents(result, params)
      text, default_mime = case result
      when String then [ result, 'text/plain' ]
      when Hash, Array then [ result.to_json, 'application/json' ]
      else raise TypeError, "#{self.class.name}#read or its rescue_from handler must return a String, Hash or Array, got #{result.class}"
      end
      uri = self.class.uri.gsub(URI_VARIABLE) { params.fetch(Regexp.last_match(1).to_sym) }
      MCP::Resource::TextContents.new(text:, uri:, mime_type: self.class.mime_type || default_mime)
    end
  end
end
