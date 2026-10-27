class McpController < ApplicationController
  include ActionModelContext::Server

  around_action :switch_locale

  private

  def mcp_context = { user: request.headers['X-User'] }

  def switch_locale(&) = I18n.with_locale(request.headers['Accept-Language'].presence_in(%w[en fr]) || :en, &)
end
