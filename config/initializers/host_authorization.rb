# frozen_string_literal: true

if Rails.env.production?
  Rails.application.config.host_authorization = {
    exclude: ->(request) { request.path == "/up" }
  }

  Rails.application.config.hosts << ->(host) { Ugo::HostAuthorization.allowed_host?(host) }
end
