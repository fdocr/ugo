# frozen_string_literal: true

require "test_helper"

class CloudflareConnectingIpTest < ActiveSupport::TestCase
  setup do
    @original_extra = ENV["TRUSTED_PROXIES_EXTRA"]
    @original_debug = ENV["DEBUG_CLIENT_IP"]
    ENV.delete("DEBUG_CLIENT_IP")
    TrustedProxies.configure!
  end

  teardown do
    ENV["TRUSTED_PROXIES_EXTRA"] = @original_extra
    ENV["DEBUG_CLIENT_IP"] = @original_debug
    TrustedProxies.configure!
  end

  test "prefers CF-Connecting-IP when Cloudflare proxies are configured" do
    ENV["TRUSTED_PROXIES_EXTRA"] = "173.245.48.0/20"
    TrustedProxies.configure!

    env = build_env(
      "REMOTE_ADDR" => "10.0.0.1",
      "HTTP_X_FORWARDED_FOR" => "173.245.48.1",
      "HTTP_CF_CONNECTING_IP" => "170.203.199.134"
    )

    assert_equal "170.203.199.134", remote_ip_from_stack(env)
  end

  test "falls back to RemoteIp when CF-Connecting-IP is absent" do
    ENV["TRUSTED_PROXIES_EXTRA"] = "173.245.48.0/20"
    TrustedProxies.configure!

    env = build_env(
      "REMOTE_ADDR" => "173.245.48.1",
      "HTTP_X_FORWARDED_FOR" => "170.203.199.134"
    )

    assert_equal "170.203.199.134", remote_ip_from_stack(env)
  end

  test "ignores CF-Connecting-IP when Cloudflare proxies are not configured" do
    ENV.delete("TRUSTED_PROXIES_EXTRA")
    TrustedProxies.configure!

    env = build_env(
      "REMOTE_ADDR" => "203.0.113.9",
      "HTTP_CF_CONNECTING_IP" => "170.203.199.134"
    )

    assert_equal "203.0.113.9", remote_ip_from_stack(env)
  end

  test "ignores invalid CF-Connecting-IP values" do
    ENV["TRUSTED_PROXIES_EXTRA"] = "173.245.48.0/20"
    TrustedProxies.configure!

    env = build_env(
      "REMOTE_ADDR" => "203.0.113.9",
      "HTTP_CF_CONNECTING_IP" => "not-an-ip"
    )

    assert_equal "203.0.113.9", remote_ip_from_stack(env)
  end

  test "logs one diagnostic line when DEBUG_CLIENT_IP is enabled" do
    ENV["TRUSTED_PROXIES_EXTRA"] = "173.245.48.0/20"
    ENV["DEBUG_CLIENT_IP"] = "true"
    TrustedProxies.configure!

    env = build_env(
      "REMOTE_ADDR" => "10.0.0.1",
      "HTTP_CF_CONNECTING_IP" => "170.203.199.134"
    )

    log_output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::TaggedLogging.new(Logger.new(log_output))

    begin
      remote_ip_from_stack(env)
      assert_match(/\[client_ip\].*source=cf_connecting_ip/, log_output.string)
    ensure
      Rails.logger = original_logger
    end
  end

  private

  def build_env(overrides = {})
    Rack::MockRequest.env_for("/", overrides)
  end

  def remote_ip_from_stack(env)
    app = CloudflareConnectingIp::Middleware.new(->(_inner_env) { [ 200, {}, [] ] })
    ActionDispatch::RemoteIp.new(app).call(env)
    ActionDispatch::Request.new(env).remote_ip
  end
end
