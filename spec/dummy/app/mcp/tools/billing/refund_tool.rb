module Billing
  class RefundTool < ApplicationTool
    argument :amount, :integer, required: true

    def call(amount:) = "Refunded #{amount}"
  end
end
