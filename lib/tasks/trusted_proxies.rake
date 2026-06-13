# frozen_string_literal: true

namespace :trusted_proxies do
  desc "Fetch Cloudflare IP ranges and update config/cloudflare_cidrs.txt"
  task cloudflare: :environment do
    cidrs = TrustedProxies::Cloudflare.fetch_cidrs
    TrustedProxies.write_baked_cidrs!(cidrs)

    puts <<~MSG
      Wrote #{cidrs.size} CIDRs to #{TrustedProxies.baked_cidrs_path}

      Release builds refresh this file automatically before docker build.
      Commit the updated file when refreshing locally so the offline fallback stays current.
    MSG
  rescue StandardError => e
    warn "Could not fetch Cloudflare IP ranges: #{e.message}"
    if TrustedProxies.baked_cidrs_path.exist?
      warn "Using existing #{TrustedProxies.baked_cidrs_path} (#{TrustedProxies.baked_ipaddrs.size} CIDRs)"
    else
      warn "Download manually from:"
      warn "  #{TrustedProxies::Cloudflare::IPV4_URL}"
      warn "  #{TrustedProxies::Cloudflare::IPV6_URL}"
      exit 1
    end
  end
end
