class WhoAmITool < ApplicationTool
  rescue_from(KeyError) { raise ActionModelContext::Error, 'Unknown user' }

  def call = { user: context.fetch(:user) }
end
