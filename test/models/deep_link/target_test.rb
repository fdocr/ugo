# frozen_string_literal: true

require "test_helper"

class DeepLink::TargetTest < ActiveSupport::TestCase
  test "normalizes https URL and strips fragment" do
    assert_equal "https://Example.com/path",
      DeepLink::Target.new("https://Example.com/path#section").url
  end

  test "rejects non-http schemes" do
    assert_raises(DeepLink::Target::InvalidTarget) do
      DeepLink::Target.new("javascript:alert(1)").url
    end
  end

  test "exposes the lowercased host" do
    assert_equal "example.com", DeepLink::Target.new("https://Example.com/path").host
  end

  test "allowed domains match host" do
    assert DeepLink::Target.new("https://app.example.com/x").allowed?(domains: "example.com")
    assert_not DeepLink::Target.new("https://evil.com/x").allowed?(domains: "example.com")
  end

  test "parses the URL only once across url, host and allowlist checks" do
    calls = 0
    original = HttpUrlValidator.method(:parse)
    stubs = ActiveSupport::Testing::SimpleStubs.new
    stubs.stub_object(HttpUrlValidator, :parse) do |value|
      calls += 1
      original.call(value)
    end

    target = DeepLink::Target.new("https://app.example.com/x#frag")
    assert_equal "https://app.example.com/x", target.url
    assert_equal "app.example.com", target.host
    assert target.allowed?(domains: "example.com")
    assert_equal 1, calls, "expected the bounce target to be parsed exactly once"
  ensure
    stubs&.unstub_all!
  end
end
