require 'rails/generators'
require 'active_support/core_ext/object/blank'

module ActionModelContext
  # Generators of the install, tools, resources and prompts.
  #
  # @api private
  module Generators
    TYPES = {
      'string' => :string, 'text' => :string, 'integer' => :integer,
      'float' => :number, 'decimal' => :number, 'number' => :number,
      'boolean' => :boolean, 'array' => :array, 'object' => :object
    }.freeze
    PLACEHOLDERS = { string: "'example'", integer: '1', number: '1.0', boolean: 'true', array: '[]', object: '{}' }.freeze

    # An argument read from the command line of a generator.
    #
    # @api private
    Argument = Data.define(:name, :type, :required) do
      # Parses `name:type:required`, without the type when `typed` is false.
      #
      # @param spec [String] the argument on the command line
      # @param typed [Boolean] whether it may hold a type
      # @return [Argument]
      # @raise [Thor::Error] when the argument is invalid
      def self.parse(spec, typed: true)
        name, *parts = spec.split(':')
        required = parts.delete('required') ? true : false
        raise Thor::Error, "Invalid argument #{spec.inspect}, expected name#{':type' if typed}[:required]" if name.blank? || parts.size > (typed ? 1 : 0)

        new(name:, type: typed ? resolve_type(parts.first, spec) : nil, required:)
      end

      # Maps a command line type to a JSON Schema type.
      #
      # @param type [String, nil] the type, `:string` being the default
      # @param spec [String] the argument on the command line, for the error message
      # @return [Symbol]
      # @raise [Thor::Error] when the type is unknown
      def self.resolve_type(type, spec)
        return :string if type.nil?

        TYPES.fetch(type) { raise Thor::Error, "Unknown type #{type.inspect} in #{spec.inspect}, expected one of: #{TYPES.keys.join(', ')}" }
      end

      # Gives the keyword of the argument in the generated signature.
      #
      # @return [String]
      def keyword = required ? "#{name}:" : "#{name}: nil"

      # Gives the argument with an example value, for the generated test.
      #
      # @return [String]
      def placeholder = "#{name}: #{PLACEHOLDERS.fetch(type)}"
    end
  end
end
