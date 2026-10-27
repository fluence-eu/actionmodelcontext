Rails.application.routes.draw do
  resource :mcp, controller: :mcp, only: %i[show create destroy]
end
