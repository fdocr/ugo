require "test_helper"

class AppConfigTest < ActiveSupport::TestCase
  setup do
    AppConfig.send(:reset_caches!)
  end

  teardown do
    AppConfig.send(:reset_caches!)
  end

  test "self_hosted? is memoized at the class level after first computation" do
    setup_app_config_as_main_app!

    AppConfig.self_hosted?
    AppConfig.main_app?

    callback = ->(_, _, _, _, payload) {
      assert_not_match(/app_configs/i, payload[:sql] || "",
        "self_hosted?/main_app? must not hit the database after the first call")
    }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      10.times { AppConfig.self_hosted? }
      10.times { AppConfig.main_app? }
    end

    assert_equal false, AppConfig.self_hosted?
    assert_equal true, AppConfig.main_app?
  end

  test "memo is busted when the AppConfig row is updated" do
    setup_app_config_as_main_app!
    assert_not AppConfig.self_hosted?

    setup_app_config_as_self_hosted!
    assert AppConfig.self_hosted?
  end

  # ------------------------------------------------------------------
  # Polar configuration
  # ------------------------------------------------------------------
  test "configure_polar! uses DB values when present" do
    AppConfig.shared.update!(
      polar_access_token: "db-token",
      polar_webhook_secret: "db-secret",
      polar_sandbox: true
    )

    AppConfig.configure_polar!

    assert_equal "db-token", Polar.config.access_token
    assert_equal "db-secret", Polar.config.webhook_secret
    assert_equal true, Polar.config.sandbox
  end

  test "configure_polar! falls back to ENV when DB values are blank" do
    AppConfig.shared.update!(polar_access_token: "", polar_webhook_secret: "", polar_sandbox: false)

    ENV["POLAR_ACCESS_TOKEN"] = "env-token"
    ENV["POLAR_WEBHOOK_SECRET"] = "env-secret"
    ENV["POLAR_SANDBOX"] = "true"

    AppConfig.configure_polar!

    assert_equal "env-token", Polar.config.access_token
    assert_equal "env-secret", Polar.config.webhook_secret
    assert_equal true, Polar.config.sandbox
  ensure
    ENV.delete("POLAR_ACCESS_TOKEN")
    ENV.delete("POLAR_WEBHOOK_SECRET")
    ENV.delete("POLAR_SANDBOX")
  end

  test "configure_polar! is a no-op when no access token exists" do
    AppConfig.shared.update!(polar_access_token: "")
    ENV.delete("POLAR_ACCESS_TOKEN")

    Polar.configure { |c| c.access_token = "sentinel" }
    AppConfig.configure_polar!
    assert_equal "sentinel", Polar.config.access_token
  end

  test "polar_product_id returns DB value when set" do
    AppConfig.shared.update!(
      polar_basic_product_id: "db-basic-id",
      polar_growth_product_id: "db-growth-id"
    )

    assert_equal "db-basic-id", AppConfig.polar_product_id(:basic)
    assert_equal "db-growth-id", AppConfig.polar_product_id(:growth)
  end

  test "polar_product_id falls back to ENV when DB value is blank" do
    AppConfig.shared.update!(polar_basic_product_id: "", polar_growth_product_id: "")

    ENV["POLAR_BASIC_PRODUCT_ID"] = "env-basic-id"
    ENV["POLAR_GROWTH_PRODUCT_ID"] = "env-growth-id"

    assert_equal "env-basic-id", AppConfig.polar_product_id(:basic)
    assert_equal "env-growth-id", AppConfig.polar_product_id(:growth)
  ensure
    ENV.delete("POLAR_BASIC_PRODUCT_ID")
    ENV.delete("POLAR_GROWTH_PRODUCT_ID")
  end

  test "polar_product_id returns nil for unknown plan" do
    assert_nil AppConfig.polar_product_id(:enterprise)
  end
end
