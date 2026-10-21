module ActionModelContext
  module Naming
    def self.default_name(klass, suffix:) = klass.name&.delete_suffix(suffix)&.underscore&.tr("/", "_")
  end
end
