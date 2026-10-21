module ActionModelContext
  class Resource
    include Primitive

    primitive kind: :resources, suffix: "Resource"

    URI_VARIABLE = /\{([A-Za-z_]\w*)\}/

    class << self
      def uri(value = nil)
        return @declared_uri = value if value

        @declared_uri
      end

      def mime_type(value = nil)
        return @declared_mime_type = value if value

        @declared_mime_type
      end

      def resource_name(name = nil) = primitive_name(name)

      def concrete? = !uri.nil? && instance_method(:read).owner != Resource

      def template? = uri.include?("{")

      def uri_variables = uri.scan(URI_VARIABLE).flatten.map(&:to_sym)

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

      def definition = { name: resource_name, title:, description:, mime_type: }
    end

    def read(**) = raise(NotImplementedError, "#{self.class.name}#read is not implemented")

    def read_mcp(params)
      params = params.slice(*self.class.uri_variables)
      to_contents(with_rescue { read(**params) }, params)
    rescue Error => e
      raise_invalid_params(e)
    end

    private

    def to_contents(result, params)
      text, default_mime = case result
      when String then [ result, "text/plain" ]
      when Hash, Array then [ result.to_json, "application/json" ]
      else raise TypeError, "#{self.class.name}#read or its rescue_from handler must return a String, Hash or Array, got #{result.class}"
      end
      uri = self.class.uri.gsub(URI_VARIABLE) { params.fetch(Regexp.last_match(1).to_sym) }
      MCP::Resource::TextContents.new(text:, uri:, mime_type: self.class.mime_type || default_mime)
    end
  end
end
