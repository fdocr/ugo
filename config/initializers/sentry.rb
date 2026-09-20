# GlitchTip speaks the Sentry protocol. The SDK is a no-op without
# GLITCHTIP_DSN, including in test, so CI never phones home.
dsn = ENV["GLITCHTIP_DSN"].presence
return if dsn.blank? || Rails.env.test?

Sentry.init do |config|
  config.dsn = dsn
  config.environment = Rails.env
  config.traces_sample_rate = 0.01
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  # sentry-ruby 7 sends Rails logs by default. The hosted free tier is 1k
  # events/month, so keep this to exceptions (and 1% of transactions).
  config.rails.structured_logging.enabled = false
  config.before_send_log = ->(_log) { nil }
end
