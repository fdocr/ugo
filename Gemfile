source "https://rubygems.org"

gem "rails", "~> 8.1"
gem "propshaft"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.22"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

gem "mission_control-jobs", "~> 1.0", ">= 1.0.2"
gem "bootsnap", require: false
gem "thruster", require: false
gem "tailwindcss-rails", "~> 4.4"
gem "cloudflare-turnstile-rails", "~> 1.0"
gem "maxminddb", "~> 0.1.22"
gem "device_detector", "~> 1.1", ">= 1.1.3"
gem "crawler_detect", "~> 1.2"
gem "faraday", "~> 2.14"
gem "faraday-follow_redirects", "~> 0.5"
gem "rqrcode", "~> 3.1"
gem "pagy", "~> 43.5"
gem "dotenv-rails", "~> 3.1"
gem "honeybadger", "~> 6.9"
gem "flipper", "~> 1.4"
gem "flipper-active_record", "~> 1.3"

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # Minitest [https://github.com/minitest/minitest]
  gem "minitest"

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Faker [https://github.com/faker-ruby/faker]
  gem "faker", "~> 3.8"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
  gem "letter_opener", "~> 1.10"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end

group :development, :test do
  # Headless Chrome driver used by bin/ui-tour to capture screenshot smoke tours.
  gem "cuprite", "~> 0.16"
end

gem "polar_sh", "~> 0.2.0"

gem "sitemap_generator", "~> 7.0"
