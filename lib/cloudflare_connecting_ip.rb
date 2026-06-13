# frozen_string_literal: true

# Prefer Cloudflare's CF-Connecting-IP for request.remote_ip when a Cloudflare
# edge IP appears in the proxy chain (from config/cloudflare_cidrs.txt baked into
# the image) or when CLOUDFLARE_PROXIED=true. Falls back to ActionDispatch::RemoteIp
# when the header is absent or cannot be trusted.
module CloudflareConnectingIp
  HEADER = "HTTP_CF_CONNECTING_IP"

  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      apply_connecting_ip!(env)
      @app.call(env)
    end

    private

    def apply_connecting_ip!(env)
      connecting_ip = env[HEADER]&.strip
      remote_ip_before = env["action_dispatch.remote_ip"]
      source = "remote_ip"

      if connecting_ip.present? && valid_client_ip?(connecting_ip) && trust_connecting_ip_header?(env)
        env["action_dispatch.remote_ip"] = connecting_ip
        source = "cf_connecting_ip"
      end

      log_client_ip(env, remote_ip_before:, resolved: env["action_dispatch.remote_ip"], source:)
    end

    def trust_connecting_ip_header?(env)
      return true if TrustedProxies.cloudflare_proxy_mode?

      TrustedProxies.cloudflare_ipaddr?(env["REMOTE_ADDR"]) ||
        forwarded_ips(env).any? { |ip| TrustedProxies.cloudflare_ipaddr?(ip) }
    end

    def forwarded_ips(env)
      env["HTTP_X_FORWARDED_FOR"].to_s.split(",").map(&:strip).reject(&:blank?)
    end

    def valid_client_ip?(value)
      IPAddr.new(value)
      true
    rescue IPAddr::InvalidAddressError
      false
    end

    def log_client_ip(env, remote_ip_before:, resolved:, source:)
      return unless debug_client_ip?

      Rails.logger.info(
        "[client_ip] cf_connecting_ip=#{env[HEADER].inspect} " \
        "x_forwarded_for=#{env['HTTP_X_FORWARDED_FOR'].inspect} " \
        "remote_addr=#{env['REMOTE_ADDR'].inspect} " \
        "remote_ip_before=#{remote_ip_before.inspect} " \
        "resolved=#{resolved.inspect} source=#{source}"
      )
    end

    def debug_client_ip?
      ActiveModel::Type::Boolean.new.cast(ENV["DEBUG_CLIENT_IP"])
    end
  end
end
