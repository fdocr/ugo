# Singleton model for site-wide configuration.
# Sensitive fields are encrypted at rest via Active Record Encryption.
#
# Usage: AppConfig.shared.app_name / AppConfig.shared.update!(app_name: "x")
class AppConfig < ApplicationRecord
  include DeepLinkSettings

  UGO_DOMAIN = "ugo.cr".freeze

  encrypts :smtp_password, :smtp_username, :admin_api_key, :setup_code,
           :polar_access_token, :polar_webhook_secret, :honeybadger_api_key

  # Setup completion + hosting mode are effectively immutable for the lifetime
  # of a process (only ever flipped via setup or admin settings update). Bust
  # the class-level memo whenever the row changes so admin updates take effect
  # in the same process and tests can swap modes between scenarios.
  after_update_commit :reset_class_caches

  def self.shared
    first_or_create!
  end

  # ------------------------------------------------------------------
  # Domain / hosting helpers (memoized to keep them off the request hot path)
  # ------------------------------------------------------------------
  def self.main_app?
    return @main_app if defined?(@main_app)
    @main_app = (shared.app_domain == UGO_DOMAIN)
  end

  def self.self_hosted?
    return @self_hosted if defined?(@self_hosted)
    config = shared
    @self_hosted = config.setup_completed && config.app_domain != UGO_DOMAIN
  end

  def self.reset_caches!
    remove_instance_variable(:@self_hosted) if defined?(@self_hosted)
    remove_instance_variable(:@main_app) if defined?(@main_app)
  end

  # ------------------------------------------------------------------
  # Polar (payments) configuration
  # ------------------------------------------------------------------
  def self.configure_polar!
    cfg = shared
    access_token = cfg.polar_access_token.presence || ENV["POLAR_ACCESS_TOKEN"]
    return if access_token.blank?

    Polar.configure do |config|
      config.access_token = access_token
      config.sandbox = cfg.polar_sandbox || ENV.fetch("POLAR_SANDBOX", "false") == "true"
      config.webhook_secret = cfg.polar_webhook_secret.presence || ENV["POLAR_WEBHOOK_SECRET"]
    end
  end

  def self.polar_product_id(plan)
    cfg = shared
    case plan.to_s
    when "basic"
      cfg.polar_basic_product_id.presence || ENV["POLAR_BASIC_PRODUCT_ID"]
    when "growth"
      cfg.polar_growth_product_id.presence || ENV["POLAR_GROWTH_PRODUCT_ID"]
    end
  end

  # ------------------------------------------------------------------
  # Honeybadger configuration
  # ------------------------------------------------------------------
  def self.honeybadger_key
    cfg = shared rescue nil
    cfg&.honeybadger_api_key.presence || ENV["HONEYBADGER_API_KEY"]
  end

  # ------------------------------------------------------------------
  # SMTP configuration
  # ------------------------------------------------------------------
  def self.configure_smtp!
    cfg = shared
    address = cfg.smtp_address.presence
    return if address.blank?

    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.smtp_settings = {
      address: address,
      port: cfg.smtp_port,
      user_name: cfg.smtp_username.presence,
      password: cfg.smtp_password.presence,
      authentication: :plain,
      enable_starttls_auto: true
    }

    ActionMailer::Base.default_url_options = { host: cfg.app_domain } if cfg.app_domain.present?
  end

  private

  def reset_class_caches
    self.class.reset_caches!
  end
end
