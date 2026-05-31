# frozen_string_literal: true

require "test_helper"
require "rake"

class TrustedProxiesRakeTest < ActiveSupport::TestCase
  def setup
    @rake = Rake::Application.new
    Rake.application = @rake
    load Rails.root.join("lib/tasks/trusted_proxies.rake")
    Rake::Task.define_task(:environment)
    @task = @rake["trusted_proxies:cloudflare"]
    @task.reenable
  end

  test "cloudflare task prints TRUSTED_PROXIES_EXTRA line" do
    original = TrustedProxies::Cloudflare.method(:fetch_cidrs)
    TrustedProxies::Cloudflare.define_singleton_method(:fetch_cidrs) { [ "173.245.48.0/20", "2400:cb00::/32" ] }

    assert_output(/TRUSTED_PROXIES_EXTRA=173\.245\.48\.0\/20,2400:cb00::\/32/) do
      @task.invoke
    end
  ensure
    TrustedProxies::Cloudflare.define_singleton_method(:fetch_cidrs, original)
    @task.reenable
  end
end
