# frozen_string_literal: true

require "test_helper"

class AppConfigDeepLinkTest < ActiveSupport::TestCase
  setup { @config = app_configs(:one) }

  test "validates ios app id format when deep linking enabled" do
    @config.deep_link_enabled = true
    @config.deep_link_ios_app_ids = "not-valid"
    assert_not @config.valid?
    assert_includes @config.errors[:deep_link_ios_app_ids], "contains an invalid app ID: not-valid"
  end

  test "validates default destination url" do
    @config.deep_link_enabled = true
    @config.deep_link_default_destination = "ftp://bad"
    assert_not @config.valid?
    assert @config.errors[:deep_link_default_destination].present?
  end

  test "apple_app_site_association is nil without ios app ids" do
    @config.deep_link_ios_app_ids = ""
    assert_nil @config.apple_app_site_association
  end

  test "apple_app_site_association builds the applinks payload for each app id" do
    @config.deep_link_ios_app_ids = "ABCDE12345.com.example.app, FGHIJ67890.com.example.other"
    payload = @config.apple_app_site_association

    details = payload[:applinks][:details]
    assert_equal [ "ABCDE12345.com.example.app", "FGHIJ67890.com.example.other" ], details.map { |d| d[:appID] }
    assert_equal [ "/r" ], details.first[:paths]
    assert_equal [ { "/": "/r" } ], details.first[:components]
    assert_equal @config.deep_link_ios_app_ids_list, payload[:activitycontinuation][:apps]
  end
end
