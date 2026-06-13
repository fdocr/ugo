# frozen_string_literal: true

require Rails.root.join("lib/cloudflare_connecting_ip")

# Runs immediately inside ActionDispatch::RemoteIp: RemoteIp sets
# action_dispatch.remote_ip first, then this middleware may replace it from
# CF-Connecting-IP before controllers read request.remote_ip.
Rails.application.config.middleware.insert_after(
  ActionDispatch::RemoteIp,
  CloudflareConnectingIp::Middleware
)
