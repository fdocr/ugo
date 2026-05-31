# Polar is configured from AppConfig (admin panel) with ENV fallback for local dev.
# Self-hosted installations leave these blank and Polar is simply not configured.
Rails.application.config.after_initialize do
  AppConfig.configure_polar!
rescue => e
  Rails.logger.warn "Polar configuration skipped: #{e.message}"
end
