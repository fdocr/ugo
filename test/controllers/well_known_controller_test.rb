# frozen_string_literal: true

require "test_helper"

class WellKnownControllerTest < ActionDispatch::IntegrationTest
  setup do
    @config = app_configs(:one)
    @config.update!(
      deep_link_enabled: true,
      deep_link_ios_app_ids: "ABCDE12345.com.example.app"
    )
  end

  test "apple app site association returns json when configured" do
    get "/.well-known/apple-app-site-association"
    assert_response :success
    body = JSON.parse(response.body)
    paths = body.dig("applinks", "details").first["paths"]
    assert_equal [ "/r" ], paths
    assert_includes response.headers["Cache-Control"], "public"
    assert_includes response.headers["Cache-Control"], "max-age=3600"
  end

  test "apple app site association returns 404 when disabled" do
    @config.update!(deep_link_enabled: false)
    get "/.well-known/apple-app-site-association"
    assert_response :not_found
  end

  test "asset links returns json when configured" do
    @config.update!(
      deep_link_android_asset_links: [
        {
          relation: [ "delegate_permission/common.handle_all_urls" ],
          target: {
            namespace: "android_app",
            package_name: "com.example.app",
            sha256_cert_fingerprints: [ "AA:BB:CC" ]
          }
        }
      ].to_json
    )
    get "/.well-known/assetlinks.json"
    assert_response :success
    assert_equal 1, JSON.parse(response.body).size
  end

  test "well known paths are not captured by link slug route" do
    get "/.well-known/apple-app-site-association"
    assert_response :success
    assert_equal "application/json", response.media_type
  end
end
