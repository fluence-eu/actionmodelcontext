Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.i18n.available_locales = %i[en fr]
  config.i18n.default_locale = :en
  config.i18n.fallbacks = true
end
