# frozen_string_literal: true

module TrustedProxies
  BAKED_CIDRS_PATH = Rails.root.join("config/cloudflare_cidrs.txt")

  module_function

  def baked_cidrs_path
    BAKED_CIDRS_PATH
  end

  def baked_ipaddrs
    return [] unless baked_cidrs_path.exist?

    parse_cidrs(File.read(baked_cidrs_path))
  end

  def extra_ipaddrs(value = ENV["TRUSTED_PROXIES_EXTRA"])
    parse_cidrs(value.to_s.tr(",", "\n"))
  end

  def proxy_ipaddrs
    baked_ipaddrs + extra_ipaddrs
  end

  def parse_cidrs(content)
    content.lines.filter_map do |line|
      entry = line.strip
      next if entry.blank? || entry.start_with?("#")

      IPAddr.new(entry)
    rescue IPAddr::InvalidAddressError
      raise ArgumentError, "Invalid CIDR entry: #{entry.inspect}"
    end
  end

  def write_baked_cidrs!(cidrs, path: baked_cidrs_path)
    header = <<~HEADER
      # Cloudflare orange-cloud proxy CIDRs (one per line).
      # Refreshed on every Release build; this committed copy is the offline fallback.
    HEADER
    File.write(path, header + cidrs.join("\n") + "\n")
  end

  def configure!(app = Rails.application)
    app.config.action_dispatch.trusted_proxies =
      ActionDispatch::RemoteIp::TRUSTED_PROXIES.dup + proxy_ipaddrs
  end

  # Optional short Once env when CF-Connecting-IP should be trusted but the
  # proxy chain does not expose a Cloudflare edge IP (rare).
  def cloudflare_proxy_mode?
    ActiveModel::Type::Boolean.new.cast(ENV["CLOUDFLARE_PROXIED"])
  end

  def cloudflare_ipaddr?(ip)
    return false if ip.blank?

    address = IPAddr.new(ip)
    proxy_ipaddrs.any? { |proxy| proxy.include?(address) }
  rescue IPAddr::InvalidAddressError
    false
  end
end
