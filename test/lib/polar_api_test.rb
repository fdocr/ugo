require "test_helper"

class PolarApiTest < ActiveSupport::TestCase
  setup do
    Polar.configure do |config|
      config.access_token = "tok"
      config.sandbox = false
    end
    @stubs = Faraday::Adapter::Test::Stubs.new
    PolarApi.adapter = [ :test, @stubs ]
  end

  teardown do
    @stubs.verify_stubbed_calls
  end

  test "VERSION is the pinned Polar API version" do
    assert_equal "2026-04", PolarApi::VERSION
  end

  test "create_checkout posts products to /v1/checkouts/ with Polar-Version" do
    @stubs.post("/v1/checkouts/") do |env|
      assert_equal PolarApi::VERSION, env.request_headers["Polar-Version"]
      assert_equal "Bearer tok", env.request_headers["Authorization"]
      body = JSON.parse(env.body)
      assert_equal [ "prod_basic" ], body["products"]
      assert_equal "https://ugo.cr/success", body["success_url"]
      assert_equal "buyer@example.com", body["customer_email"]
      assert_equal "42", body["metadata"]["workspace_id"]
      [ 201, { "Polar-Version" => PolarApi::VERSION }, { "url" => "https://buy.polar.sh/abc" }.to_json ]
    end

    checkout = PolarApi.create_checkout(
      products: [ "prod_basic" ],
      success_url: "https://ugo.cr/success",
      customer_email: "buyer@example.com",
      metadata: { workspace_id: "42" }
    )

    assert_equal "https://buy.polar.sh/abc", checkout.url
  end

  test "create_customer_session posts to /v1/customer-sessions/" do
    @stubs.post("/v1/customer-sessions/") do |env|
      assert_equal PolarApi::VERSION, env.request_headers["Polar-Version"]
      body = JSON.parse(env.body)
      assert_equal "cus_123", body["customer_id"]
      assert_equal "https://ugo.cr/billing", body["return_url"]
      [ 201, {}, { "customer_portal_url" => "https://polar.sh/portal/xyz" }.to_json ]
    end

    session = PolarApi.create_customer_session(
      customer_id: "cus_123",
      return_url: "https://ugo.cr/billing"
    )

    assert_equal "https://polar.sh/portal/xyz", session.customer_portal_url
  end

  test "revoke_subscription deletes /v1/subscriptions/:id" do
    @stubs.delete("/v1/subscriptions/sub_123") do |env|
      assert_equal PolarApi::VERSION, env.request_headers["Polar-Version"]
      [ 200, {}, { "id" => "sub_123", "status" => "canceled" }.to_json ]
    end

    assert PolarApi.revoke_subscription("sub_123")
  end

  test "raises PolarApi::Error on non-success responses" do
    @stubs.post("/v1/checkouts/") { [ 422, {}, { "detail" => "invalid" }.to_json ] }

    error = assert_raises(PolarApi::Error) do
      PolarApi.create_checkout(
        products: [ "prod_basic" ],
        success_url: "https://ugo.cr/success",
        customer_email: "buyer@example.com",
        metadata: {}
      )
    end

    assert_equal 422, error.status
  end

  test "uses the sandbox API host when Polar is in sandbox mode" do
    Polar.configure do |config|
      config.access_token = "tok"
      config.sandbox = true
    end
    PolarApi.reset!
    PolarApi.adapter = [ :test, Faraday::Adapter::Test::Stubs.new ]

    connection = PolarApi.send(:connection)
    assert_equal "sandbox-api.polar.sh", connection.url_prefix.host
    assert_equal PolarApi::VERSION, connection.headers["Polar-Version"]
  end
end
