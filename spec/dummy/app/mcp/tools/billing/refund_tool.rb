module Billing
  class RefundTool < ApplicationTool
    argument :amount, :integer, required: true
  end
end
