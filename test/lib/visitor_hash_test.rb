require "test_helper"

class VisitorHashTest < ActiveSupport::TestCase
  IP = "203.0.113.42"
  UA = "Mozilla/5.0 VisitorHashTest"
  LINK_ID = 1

  test "returns a 32-char hex digest" do
    hash = VisitorHash.compute(ip: IP, user_agent: UA, visitable_type: "Link", visitable_id: LINK_ID)

    assert_equal 32, hash.length
    assert_match(/\A[0-9a-f]{32}\z/, hash)
  end

  test "is deterministic within the same UTC day" do
    morning = Time.utc(2026, 5, 17, 1, 0, 0)
    evening = Time.utc(2026, 5, 17, 23, 0, 0)

    assert_equal(
      VisitorHash.compute(ip: IP, user_agent: UA, visitable_type: "Link", visitable_id: LINK_ID, at: morning),
      VisitorHash.compute(ip: IP, user_agent: UA, visitable_type: "Link", visitable_id: LINK_ID, at: evening)
    )
  end

  test "diverges across UTC days as the salt rotates" do
    today = Time.utc(2026, 5, 17, 12, 0, 0)
    tomorrow = Time.utc(2026, 5, 18, 12, 0, 0)

    assert_not_equal(
      VisitorHash.compute(ip: IP, user_agent: UA, visitable_type: "Link", visitable_id: LINK_ID, at: today),
      VisitorHash.compute(ip: IP, user_agent: UA, visitable_type: "Link", visitable_id: LINK_ID, at: tomorrow)
    )
  end

  test "diverges across different IPs" do
    at = Time.utc(2026, 5, 17, 12, 0, 0)

    assert_not_equal(
      VisitorHash.compute(ip: IP, user_agent: UA, visitable_type: "Link", visitable_id: LINK_ID, at: at),
      VisitorHash.compute(ip: "198.51.100.1", user_agent: UA, visitable_type: "Link", visitable_id: LINK_ID, at: at)
    )
  end

  test "diverges across different user agents" do
    at = Time.utc(2026, 5, 17, 12, 0, 0)

    assert_not_equal(
      VisitorHash.compute(ip: IP, user_agent: UA, visitable_type: "Link", visitable_id: LINK_ID, at: at),
      VisitorHash.compute(ip: IP, user_agent: "curl/8.4.0", visitable_type: "Link", visitable_id: LINK_ID, at: at)
    )
  end

  test "diverges across different links so visitors aren't correlated across the dataset" do
    at = Time.utc(2026, 5, 17, 12, 0, 0)

    assert_not_equal(
      VisitorHash.compute(ip: IP, user_agent: UA, visitable_type: "Link", visitable_id: 1, at: at),
      VisitorHash.compute(ip: IP, user_agent: UA, visitable_type: "Link", visitable_id: 2, at: at)
    )
  end

  test "diverges across visitable types" do
    at = Time.utc(2026, 5, 17, 12, 0, 0)

    assert_not_equal(
      VisitorHash.compute(ip: IP, user_agent: UA, visitable_type: "Link", visitable_id: 1, at: at),
      VisitorHash.compute(ip: IP, user_agent: UA, visitable_type: "DeepLink", visitable_id: 1, at: at)
    )
  end

  test "returns nil when the IP is blank" do
    assert_nil VisitorHash.compute(ip: nil, user_agent: UA, visitable_type: "Link", visitable_id: LINK_ID)
    assert_nil VisitorHash.compute(ip: "", user_agent: UA, visitable_type: "Link", visitable_id: LINK_ID)
  end
end
