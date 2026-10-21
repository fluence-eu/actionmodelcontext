require "rails/generators"

module ActionModelContext
  module Generators
    TYPES = {
      "string" => :string, "text" => :string, "integer" => :integer,
      "float" => :number, "decimal" => :number, "number" => :number,
      "boolean" => :boolean, "array" => :array, "object" => :object
    }.freeze
    PLACEHOLDERS = { string: '"example"', integer: "1", number: "1.0", boolean: "true", array: "[]", object: "{}" }.freeze

    Argument = Data.define(:name, :type, :required) do
      def self.parse(spec, typed: true)
        name, *parts = spec.split(":")
        required = parts.delete("required") ? true : false
        raise Thor::Error, "Invalid argument #{spec.inspect}, expected name#{':type' if typed}[:required]" if name.blank? || parts.size > (typed ? 1 : 0)

        new(name:, type: typed ? resolve_type(parts.first, spec) : nil, required:)
      end

      def self.resolve_type(type, spec)
        return :string if type.nil?

        TYPES.fetch(type) { raise Thor::Error, "Unknown type #{type.inspect} in #{spec.inspect}, expected one of: #{TYPES.keys.join(', ')}" }
      end

      def keyword = required ? "#{name}:" : "#{name}: nil"

      def placeholder = "#{name}: #{PLACEHOLDERS.fetch(type)}"
    end
  end
end
