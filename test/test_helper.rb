ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # AppConfig.self_hosted?/main_app? are memoized at the class level for
    # production performance (the link redirect hot path reads them on every
    # request). Tests need a clean slate per case so that the previous test's
    # transactional state — which is rolled back on the DB but not in Ruby
    # memory — doesn't leak into the next test's hosting-mode resolution.
    setup do
      AppConfig.send(:reset_caches!)
      # Clear the controller cache store between tests so rate_limit
      # counters from one test don't bleed into the next.
      ActionController::Base.cache_store.clear
    end
    teardown { AppConfig.send(:reset_caches!) }

    def with_turnstile_keys(site:, secret:)
      old_site = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
      old_secret = ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
      ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = site
      ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = secret
      Cloudflare::Turnstile::Rails.configure do |config|
        config.site_key = site
        config.secret_key = secret
      end
      yield
    ensure
      ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"] = old_site
      ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"] = old_secret
      Cloudflare::Turnstile::Rails.configure do |config|
        config.site_key = old_site
        config.secret_key = old_secret
      end
    end

    private

    # Configure AppConfig as the main app (ugo.cr). This is the default
    # state from the app_configs fixture, so usually not needed explicitly.
    def setup_app_config_as_main_app!
      AppConfig.shared.update!(
        setup_completed: true,
        app_domain: "ugo.cr"
      )
    end

    # Configure AppConfig as a self-hosted installation. Call this in
    # tests that need to exercise self-hosted behavior.
    def setup_app_config_as_self_hosted!
      AppConfig.shared.update!(
        setup_completed: true,
        app_domain: "links.mycompany.com"
      )
    end
  end
end
