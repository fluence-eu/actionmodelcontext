class FailingTool < ApplicationTool
  def call = raise("secret internals")
end
