# frozen_string_literal: true

require "test_helper"

class TrustedProxiesCloudflareTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:status, :body, keyword_init: true) do
    def success?
      status == 200
    end
  end

  class FakeConnection
    def initialize(responses)
      @responses = responses
    end

    def get(url)
      @responses.fetch(url)
    end
  end

  test "fetch_cidrs combines v4 and v6 lists" do
    connection = FakeConnection.new({
      TrustedProxies::Cloudflare::IPV4_URL => FakeResponse.new(status: 200, body: "173.245.48.0/20\n"),
      TrustedProxies::Cloudflare::IPV6_URL => FakeResponse.new(status: 200, body: "2400:cb00::/32\n")
    })

    cidrs = TrustedProxies::Cloudflare.fetch_cidrs(connection: connection)
    assert_equal [ "173.245.48.0/20", "2400:cb00::/32" ], cidrs
  end

  test "fetch_cidrs raises on HTTP failure" do
    connection = FakeConnection.new({
      TrustedProxies::Cloudflare::IPV4_URL => FakeResponse.new(status: 500, body: ""),
      TrustedProxies::Cloudflare::IPV6_URL => FakeResponse.new(status: 200, body: "")
    })

    assert_raises(RuntimeError) { TrustedProxies::Cloudflare.fetch_cidrs(connection: connection) }
  end
end
