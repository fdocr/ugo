# frozen_string_literal: true

Rails.application.config.after_initialize do
  TrustedProxies.configure! if Rails.env.production?
end
