module ActionModelContext
  module Translation
    def self.lookup(kind, name, *path)
      return unless name

      I18n.t(path.last, scope: [ :action_model_context, kind, name, *path[0...-1] ], default: nil)
    end

    def self.argument(kind, name, argument, key)
      value = lookup(kind, name, :arguments, argument)
      value.is_a?(Hash) ? value[key] : (value if key == :description)
    end
  end
end
