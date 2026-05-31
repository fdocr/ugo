# frozen_string_literal: true

require "test_helper"

class DeepLinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @config = app_configs(:one)
    @config.update!(
      deep_link_enabled: true,
      deep_link_default_destination: "",
      deep_link_allowed_domains: ""
    )
  end

  test "bounce redirects to r target at /r and defers visit recording to a job" do
    assert_enqueued_with(job: RecordVisitJob) do
      assert_no_difference "DeepLink.count" do
        get "/r?r=https://example.com/landing"
      end
    end
    assert_redirected_to "https://example.com/landing"
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "the enqueued job creates the deep link and its visit off the request" do
    perform_enqueued_jobs do
      get "/r?r=https://example.com/landing"
    end

    deep_link = DeepLink.find_by(destination_url: "https://example.com/landing")
    assert_equal "example.com", deep_link.destination_host
    assert_equal 1, deep_link.visits.count
  end

  test "bounce uses default destination when r is absent on /r" do
    @config.update!(deep_link_default_destination: "https://example.com/home")
    get deep_link_bounce_path
    assert_redirected_to "https://example.com/home"
  end

  test "root is unaffected when deep linking enabled with default destination" do
    @config.update!(deep_link_default_destination: "https://example.com/home")
    get root_path
    assert_response :success
    assert_select "h1", text: /Share smarter links and own your data/
  end

  test "bounce is disabled when feature is off" do
    @config.update!(deep_link_enabled: false)
    get "/r?r=https://example.com/landing"
    assert_response :not_found
  end

  test "disabled bounce does not hijack root" do
    @config.update!(deep_link_enabled: false, deep_link_default_destination: "https://example.com/home")
    get root_path
    assert_response :success
    assert_select "h1", text: /Share smarter links and own your data/
  end

  test "bounce rejects disallowed domain" do
    @config.update!(deep_link_allowed_domains: "allowed.example.com")
    get "/r?r=https://other.example.com/path"
    assert_response :forbidden
  end

  test "bounce returns bad request for invalid url" do
    get "/r?r=not-a-url"
    assert_response :bad_request
  end

  test "rate limit returns 429" do
    30.times { get "/r?r=https://example.com/a", headers: { "REMOTE_ADDR" => "203.0.113.50" } }
    get "/r?r=https://example.com/a", headers: { "REMOTE_ADDR" => "203.0.113.50" }
    assert_response :too_many_requests
  end
end
