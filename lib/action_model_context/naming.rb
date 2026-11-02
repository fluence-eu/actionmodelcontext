module ActionModelContext
  # Derives the default name of a primitive.
  #
  # @api private
  module Naming
    # Builds the name from the class: `Billing::RefundTool` gives `billing_refund`.
    #
    # @param klass [Class] the primitive class
    # @param suffix [String] the class name suffix to drop
    # @return [String, nil] nil for an anonymous class
    def self.default_name(klass, suffix:) = klass.name&.delete_suffix(suffix)&.underscore&.tr('/', '_')
  end
end
