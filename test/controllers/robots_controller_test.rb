# frozen_string_literal: true

require "test_helper"

class RobotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @config = app_configs(:one)
  end

  test "robots.txt includes sitemap URL for main app" do
    setup_app_config_as_main_app!

    get "/robots.txt"

    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_match %r{Sitemap: https://ugo\.cr/sitemap\.xml\.gz}, response.body
    assert_includes response.headers["Cache-Control"], "public"
    assert_includes response.headers["Cache-Control"], "max-age=3600"
  end

  test "robots.txt includes sitemap URL for self-hosted domain" do
    setup_app_config_as_self_hosted!

    get "/robots.txt"

    assert_response :success
    assert_match %r{Sitemap: https://links\.mycompany\.com/sitemap\.xml\.gz}, response.body
  end

  test "robots.txt omits sitemap when setup is incomplete" do
    @config.update!(setup_completed: false, app_domain: "")

    get "/robots.txt"

    assert_response :success
    assert_includes response.body, "robotstxt.org"
    assert_not_includes response.body, "Sitemap:"
  end

  test "robots.txt is not captured by link slug route" do
    setup_app_config_as_main_app!

    get "/robots.txt"

    assert_response :success
    assert_equal "text/plain", response.media_type
  end
end
