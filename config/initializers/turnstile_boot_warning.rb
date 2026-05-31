Rails.application.config.after_initialize do
  next unless Rails.env.production?

  if AppConfig.main_app? && ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"].blank?
    Rails.logger.warn(
      "[ugo] CLOUDFLARE_TURNSTILE_SECRET_KEY is not set — sign-up bot protection is disabled on the managed app"
    )
  end
rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
  nil
end
