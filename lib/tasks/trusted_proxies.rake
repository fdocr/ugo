# frozen_string_literal: true

namespace :trusted_proxies do
  desc "Fetch Cloudflare IP ranges and print TRUSTED_PROXIES_EXTRA for Once Environment settings"
  task cloudflare: :environment do
    cidrs = TrustedProxies::Cloudflare.fetch_cidrs
    value = cidrs.join(",")

    puts <<~MSG
      Paste this value into Once → Settings (s) → Environment (v):

        Key:   TRUSTED_PROXIES_EXTRA
        Value: (the line below)

      TRUSTED_PROXIES_EXTRA=#{value}

      #{cidrs.size} CIDRs (#{value.length} characters). Press Done in Once to redeploy.
    MSG
  rescue StandardError => e
    warn "Could not fetch Cloudflare IP ranges: #{e.message}"
    warn "Download manually and join with commas:"
    warn "  #{TrustedProxies::Cloudflare::IPV4_URL}"
    warn "  #{TrustedProxies::Cloudflare::IPV6_URL}"
    exit 1
  end
end
