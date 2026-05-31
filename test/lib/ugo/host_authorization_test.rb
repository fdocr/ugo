# frozen_string_literal: true

require "test_helper"

class UgoHostAuthorizationTest < ActiveSupport::TestCase
  test "allows any host before setup is completed" do
    AppConfig.shared.update!(setup_completed: false, app_domain: "links.example.com")
    assert Ugo::HostAuthorization.allowed_host?("evil.example.com")
  end

  test "allows app_domain and www after setup" do
    AppConfig.shared.update!(setup_completed: true, app_domain: "links.example.com")
    assert Ugo::HostAuthorization.allowed_host?("links.example.com")
    assert Ugo::HostAuthorization.allowed_host?("www.links.example.com")
    assert_not Ugo::HostAuthorization.allowed_host?("evil.example.com")
  end

  test "rejects unknown host when setup completed with blank domain" do
    AppConfig.shared.update!(setup_completed: true, app_domain: "")
    assert_not Ugo::HostAuthorization.allowed_host?("example.com")
  end
end
