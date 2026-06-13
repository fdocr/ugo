# frozen_string_literal: true

require "test_helper"

class TrustedProxiesTest < ActiveSupport::TestCase
  test "baked_ipaddrs loads CIDRs from config/cloudflare_cidrs.txt" do
    assert_includes TrustedProxies.baked_ipaddrs.map(&:to_s), "173.245.48.0"
  end

  test "extra_ipaddrs parses comma-separated CIDRs" do
    addrs = TrustedProxies.extra_ipaddrs("203.0.113.0/24, 2001:db8::/32")
    assert_equal 2, addrs.size
  end

  test "extra_ipaddrs raises on invalid entry" do
    assert_raises(ArgumentError) { TrustedProxies.extra_ipaddrs("not-a-cidr") }
  end

  test "configure! appends baked and extra proxies to defaults" do
    original = ENV["TRUSTED_PROXIES_EXTRA"]
    ENV["TRUSTED_PROXIES_EXTRA"] = "203.0.113.0/24"

    begin
      TrustedProxies.configure!
      proxies = Rails.application.config.action_dispatch.trusted_proxies
      assert_operator proxies.size, :>, ActionDispatch::RemoteIp::TRUSTED_PROXIES.size + TrustedProxies.baked_ipaddrs.size
      assert proxies.any? { |p| p.to_s.include?("203.0.113") }
    ensure
      ENV["TRUSTED_PROXIES_EXTRA"] = original
      TrustedProxies.configure!
    end
  end

  test "cloudflare_proxy_mode? reflects CLOUDFLARE_PROXIED" do
    original = ENV["CLOUDFLARE_PROXIED"]
    begin
      ENV.delete("CLOUDFLARE_PROXIED")
      assert_not TrustedProxies.cloudflare_proxy_mode?

      ENV["CLOUDFLARE_PROXIED"] = "true"
      assert TrustedProxies.cloudflare_proxy_mode?
    ensure
      ENV["CLOUDFLARE_PROXIED"] = original
    end
  end

  test "cloudflare_ipaddr? matches baked Cloudflare CIDRs" do
    assert TrustedProxies.cloudflare_ipaddr?("173.245.48.1")
    assert_not TrustedProxies.cloudflare_ipaddr?("203.0.113.1")
  end

  test "write_baked_cidrs! writes one CIDR per line" do
    path = Rails.root.join("tmp/test-cloudflare-cidrs.txt")
    TrustedProxies.write_baked_cidrs!([ "173.245.48.0/20", "2400:cb00::/32" ], path: path)

    contents = path.read
    assert_includes contents, "173.245.48.0/20"
    assert_includes contents, "2400:cb00::/32"
  ensure
    path.delete if path.exist?
  end

  test "remote_ip uses peer when X-Forwarded-For is absent" do
    with_trusted_proxies(ActionDispatch::RemoteIp::TRUSTED_PROXIES.dup + TrustedProxies.baked_ipaddrs) do
      env = Rack::MockRequest.env_for("/", "REMOTE_ADDR" => "203.0.113.50")

      assert_equal "203.0.113.50", remote_ip_from_env(env)
    end
  end

  test "remote_ip trusts client IP through trusted private proxy" do
    with_trusted_proxies(ActionDispatch::RemoteIp::TRUSTED_PROXIES.dup + TrustedProxies.baked_ipaddrs) do
      env = Rack::MockRequest.env_for("/",
        "REMOTE_ADDR" => "10.0.0.1",
        "HTTP_X_FORWARDED_FOR" => "203.0.113.50")

      assert_equal "203.0.113.50", remote_ip_from_env(env)
    end
  end

  test "remote_ip trusts client IP when CDN peer sends single X-Forwarded-For entry" do
    with_trusted_proxies(ActionDispatch::RemoteIp::TRUSTED_PROXIES.dup + TrustedProxies.baked_ipaddrs) do
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
