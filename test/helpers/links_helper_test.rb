require "test_helper"

class LinksHelperTest < ActionView::TestCase
  test "link_host returns the host for a normal https URL" do
    assert_equal "example.com", link_host("https://example.com/path?q=1")
  end

  test "link_host returns the host for a URL with a port" do
    assert_equal "example.com", link_host("https://example.com:8443/path")
  end

  test "link_host returns the host for a subdomain" do
    assert_equal "blog.example.com", link_host("https://blog.example.com")
  end

  test "link_host falls back to the raw URL when the host is missing" do
    assert_equal "not-a-url", link_host("not-a-url")
  end

  test "link_host falls back to the raw URL on an unparseable input" do
    assert_equal "http://[invalid", link_host("http://[invalid")
  end

  test "link_host falls back to the raw URL on a blank input" do
    assert_equal "", link_host("")
  end
end
