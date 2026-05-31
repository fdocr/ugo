# frozen_string_literal: true

require "test_helper"

class HttpUrlValidatorTest < ActiveSupport::TestCase
  class Subject
    include ActiveModel::Validations
    attr_accessor :url
    validates :url, http_url: true
  end

  test "accepts http and https URLs with a host" do
    assert build("https://example.com/path?a=1").valid?
    assert build("http://example.com").valid?
  end

  test "skips blank values so presence is opt-in" do
    assert build(nil).valid?
    assert build("").valid?
  end

  test "rejects non-http schemes" do
    %w[ftp://example.com javascript:alert(1) data:text/html,hi].each do |bad|
      record = build(bad)
      assert_not record.valid?, "expected #{bad} to be invalid"
      assert_includes record.errors[:url], "must use http or https"
    end
  end

  test "rejects scheme-less strings" do
    record = build("not-a-url")
    assert_not record.valid?
    assert_includes record.errors[:url], "must use http or https"
  end

  test "rejects http without a host" do
    record = build("http://")
    assert_not record.valid?
    assert_includes record.errors[:url], "is not a valid URL"
  end

  test "rejects malformed URLs" do
    record = build("http://exa mple.com")
    assert_not record.valid?
    assert_includes record.errors[:url], "is not a valid URL"
  end

  private

  def build(url)
    Subject.new.tap { |s| s.url = url }
  end
end
