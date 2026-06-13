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
    @path = Rails.root.join("tmp/test-cloudflare-cidrs-rake-#{SecureRandom.hex(8)}.txt")
    @original_path = TrustedProxies::BAKED_CIDRS_PATH
    TrustedProxies.send(:remove_const, :BAKED_CIDRS_PATH)
    TrustedProxies.const_set(:BAKED_CIDRS_PATH, @path)
  end

  teardown do
    TrustedProxies.send(:remove_const, :BAKED_CIDRS_PATH)
    TrustedProxies.const_set(:BAKED_CIDRS_PATH, @original_path)
    FileUtils.rm_f(@path)
    @task.reenable
  end

  test "cloudflare task writes CIDRs to the baked file" do
    original = TrustedProxies::Cloudflare.method(:fetch_cidrs)
    TrustedProxies::Cloudflare.define_singleton_method(:fetch_cidrs) { [ "173.245.48.0/20", "2400:cb00::/32" ] }

    assert_output(/Wrote 2 CIDRs to/) do
      @task.invoke
    end

    assert_includes @path.read, "173.245.48.0/20"
    assert_includes @path.read, "2400:cb00::/32"
  ensure
    TrustedProxies::Cloudflare.define_singleton_method(:fetch_cidrs, original)
    @task.reenable
  end

  test "cloudflare task keeps existing file when fetch fails" do
    TrustedProxies.write_baked_cidrs!([ "173.245.48.0/20" ], path: @path)
    original = TrustedProxies::Cloudflare.method(:fetch_cidrs)
    TrustedProxies::Cloudflare.define_singleton_method(:fetch_cidrs) { raise "network down" }

    assert_output(nil, /Using existing/) do
      @task.invoke
    end
  ensure
    TrustedProxies::Cloudflare.define_singleton_method(:fetch_cidrs, original)
    @task.reenable
  end
end
