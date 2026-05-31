# frozen_string_literal: true

module TrustedProxies
  module_function

  def extra_ipaddrs(value = ENV["TRUSTED_PROXIES_EXTRA"])
    value.to_s.split(",").filter_map do |entry|
      entry = entry.strip
      next if entry.blank?

      IPAddr.new(entry)
    rescue IPAddr::InvalidAddressError
      raise ArgumentError, "Invalid TRUSTED_PROXIES_EXTRA entry: #{entry.inspect}"
    end
  end

  def configure!(app = Rails.application)
    app.config.action_dispatch.trusted_proxies =
      ActionDispatch::RemoteIp::TRUSTED_PROXIES.dup + extra_ipaddrs
  end
end
