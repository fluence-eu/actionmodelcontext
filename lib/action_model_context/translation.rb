module ActionModelContext
  # Reads the titles and descriptions of primitives from I18n.
  #
  # @api private
  module Translation
    # Looks up a key under `action_model_context.<kind>.<name>`.
    #
    # @param kind [Symbol] `:tools`, `:resources` or `:prompts`
    # @param name [String, nil] the primitive name
    # @param path [Array<Symbol>] the path of the key
    # @return [String, Hash, nil] nil when the key is missing or the primitive has no name
    def self.lookup(kind, name, *path)
      return unless name

      I18n.t(path.last, scope: [ :action_model_context, kind, name, *path[0...-1] ], default: nil)
    end

    # Reads an argument's title or description: a plain string under `arguments.<argument>` is its description.
    #
    # @param kind [Symbol] `:tools`, `:resources` or `:prompts`
    # @param name [String, nil] the primitive name
    # @param argument [Symbol] the argument name
    # @param key [Symbol] `:title` or `:description`
    # @return [String, nil]
    def self.argument(kind, name, argument, key)
      value = lookup(kind, name, :arguments, argument)
      value.is_a?(Hash) ? value[key] : (value if key == :description)
    end
  end
end
