# frozen_string_literal: true

require "test_helper"

class TrustedProxiesTest < ActiveSupport::TestCase
  test "extra_ipaddrs parses comma-separated CIDRs" do
    addrs = TrustedProxies.extra_ipaddrs("173.245.48.0/20, 2400:cb00::/32")
    assert_equal 2, addrs.size
    assert_equal "173.245.48.0", addrs.first.to_s
  end

  test "extra_ipaddrs raises on invalid entry" do
    assert_raises(ArgumentError) { TrustedProxies.extra_ipaddrs("not-a-cidr") }
  end

  test "configure! appends extra proxies to defaults" do
    original = ENV["TRUSTED_PROXIES_EXTRA"]
    ENV["TRUSTED_PROXIES_EXTRA"] = "173.245.48.0/20"

  begin
      TrustedProxies.configure!
      proxies = Rails.application.config.action_dispatch.trusted_proxies
      assert_operator proxies.size, :>, ActionDispatch::RemoteIp::TRUSTED_PROXIES.size
      assert proxies.any? { |p| p.to_s.include?("173.245.48") }
    ensure
      ENV["TRUSTED_PROXIES_EXTRA"] = original
      TrustedProxies.configure!
    end
  end

  test "remote_ip uses peer when X-Forwarded-For is absent" do
    with_trusted_proxies(ActionDispatch::RemoteIp::TRUSTED_PROXIES.dup) do
      env = Rack::MockRequest.env_for("/", "REMOTE_ADDR" => "203.0.113.50")

      assert_equal "203.0.113.50", remote_ip_from_env(env)
    end
  end

  test "remote_ip trusts client IP through trusted private proxy" do
    with_trusted_proxies(ActionDispatch::RemoteIp::TRUSTED_PROXIES.dup) do
      env = Rack::MockRequest.env_for("/",
        "REMOTE_ADDR" => "10.0.0.1",
        "HTTP_X_FORWARDED_FOR" => "203.0.113.50")

      assert_equal "203.0.113.50", remote_ip_from_env(env)
    end
  end

  test "remote_ip trusts client IP when CDN peer sends single X-Forwarded-For entry" do
    extra = TrustedProxies.extra_ipaddrs("173.245.48.0/20")
    with_trusted_proxies(ActionDispatch::RemoteIp::TRUSTED_PROXIES.dup + extra) do
      env = Rack::MockRequest.env_for("/",
        "REMOTE_ADDR" => "173.245.48.1",
        "HTTP_X_FORWARDED_FOR" => "203.0.113.50")

      assert_equal "203.0.113.50", remote_ip_from_env(env)
    end
  end

  private

  def with_trusted_proxies(proxies)
    original = Rails.application.config.action_dispatch.trusted_proxies
    Rails.application.config.action_dispatch.trusted_proxies = proxies
    yield
  ensure
    Rails.application.config.action_dispatch.trusted_proxies = original
  end

  def remote_ip_from_env(env)
    ActionDispatch::RemoteIp.new(->(_inner) { [ 200, {}, [] ] }).call(env)
    ActionDispatch::Request.new(env).remote_ip
  end
end
