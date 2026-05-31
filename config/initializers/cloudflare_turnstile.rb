Cloudflare::Turnstile::Rails.configure do |config|
  config.site_key = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
  config.secret_key = ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
end
