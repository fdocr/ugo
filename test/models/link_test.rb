require "test_helper"

class LinkTest < ActiveSupport::TestCase
  test "banned? returns false by default" do
    link = links(:one)
    assert_not link.banned?
  end

  test "banned? returns true when banned_at is set" do
    link = links(:one)
    link.update!(banned_at: Time.current)
    assert link.banned?
  end

  test "valid https URL passes validation" do
    link = build_link(url: "https://example.com/path?a=1&b=2")
    assert link.valid?
  end

  test "valid http URL passes validation" do
    link = build_link(url: "http://example.com")
    assert link.valid?
  end

  test "javascript: URL fails validation" do
    link = build_link(url: "javascript:alert(1)")
    assert_not link.valid?
    assert_includes link.errors[:url], "must use http or https"
  end

  test "data: URL fails validation" do
    link = build_link(url: "data:text/html,<script>alert(1)</script>")
    assert_not link.valid?
    assert link.errors[:url].any?, "expected a validation error on :url"
  end

  test "ftp: URL fails validation" do
    link = build_link(url: "ftp://files.example.com/doc.pdf")
    assert_not link.valid?
    assert_includes link.errors[:url], "must use http or https"
  end

  test "scheme-less string fails validation" do
    link = build_link(url: "not-a-url")
    assert_not link.valid?
    assert_includes link.errors[:url], "must use http or https"
  end

  test "http URL without host fails validation" do
    link = build_link(url: "http://")
    assert_not link.valid?
    assert_includes link.errors[:url], "is not a valid URL"
  end

  test "URL exceeding 2048 characters fails validation" do
    long_url = "https://example.com/#{"a" * 2048}"
    link = build_link(url: long_url)
    assert_not link.valid?
    assert link.errors[:url].any? { |e| e.include?("too long") }
  end

  test "nil URL passes validation (link can be created without a destination)" do
    link = build_link(url: nil)
    assert link.valid?
  end

  test "analytics_cache_prefix is namespaced by id" do
    link = links(:one)
    assert_equal "#{link.id}_visits_charts", link.analytics_cache_prefix
  end

  test "visit_discard_reason is nil for a healthy workspace" do
    link = links(:one)
    stub_workspace(link, blocked: false, over_limit: false)
    assert_nil link.visit_discard_reason
  end

  test "visit_discard_reason reports a blocked workspace" do
    link = links(:one)
    stub_workspace(link, blocked: true, over_limit: false)
    assert_equal "workspace #{link.workspace_id} disabled (trial ended)", link.visit_discard_reason
  end

  test "visit_discard_reason reports an over-limit workspace" do
    link = links(:one)
    stub_workspace(link, blocked: false, over_limit: true)
    assert_equal "workspace #{link.workspace_id} reached its limit", link.visit_discard_reason
  end

  private

  def stub_workspace(link, blocked:, over_limit:)
    double = Struct.new(:ugo_access_blocked?, :event_limit_reached?).new(blocked, over_limit)
    link.define_singleton_method(:workspace) { double }
  end

  def build_link(url:)
    Link.new(
      name: "Test",
      slug: SecureRandom.alphanumeric(5),
      url: url,
      workspace: workspaces(:one)
    )
  end
end
