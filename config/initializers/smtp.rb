# frozen_string_literal: true

# Configure SMTP from AppConfig settings in production.
# In development, letter_opener is used instead.
Rails.application.config.after_initialize do
  next unless Rails.env.production?

  begin
    AppConfig.configure_smtp!
  rescue => e
    Rails.logger.warn "SMTP configuration skipped: #{e.message}"
  end
end
