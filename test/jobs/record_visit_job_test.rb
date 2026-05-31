require "test_helper"

class RecordVisitJobTest < ActiveJob::TestCase
  setup do
    setup_app_config_as_main_app!
  end

  test "creates a visit row on the primary database with a computed visitor_hash" do
    link = links(:one)
    timestamp = Time.current

    assert_difference "Visit.count", 1 do
      RecordVisitJob.perform_now(
        visitable: link,
        ip_address: "192.0.2.10",
        user_agent: "RecordVisitJob test/1.0",
        referer: nil,
        timestamp: timestamp
      )
    end

    visit = Visit.order(:id).last
    assert_equal "Link", visit.visitable_type
    assert_equal link.id, visit.visitable_id
    assert_equal "192.0.2.10", visit.ip_address
    assert_equal(
      VisitorHash.compute(
        ip: "192.0.2.10",
        user_agent: "RecordVisitJob test/1.0",
        visitable_type: "Link",
        visitable_id: link.id,
        at: timestamp
      ),
      visit.visitor_hash
    )
  end

  test "creates a visit for a deep link destination" do
    deep_link = DeepLink.create!(
      destination_url: "https://example.com/app",
      destination_host: "example.com"
    )
    timestamp = Time.current

    assert_difference "Visit.count", 1 do
      RecordVisitJob.perform_now(
        visitable: deep_link,
        ip_address: "192.0.2.11",
        user_agent: "RecordVisitJob test/1.0",
        referer: nil,
        timestamp: timestamp
      )
    end

    visit = Visit.order(:id).last
    assert_equal "DeepLink", visit.visitable_type
    assert_equal deep_link.id, visit.visitable_id
  end

  test "resolves a deep link by destination url, creating it off the request" do
    assert_difference [ "DeepLink.count", "Visit.count" ], 1 do
      RecordVisitJob.perform_now(
        visitable_url: "https://example.com/app",
        ip_address: "192.0.2.12",
        user_agent: "RecordVisitJob test/1.0",
        referer: nil,
        timestamp: Time.current
      )
    end

    visit = Visit.order(:id).last
    assert_equal "DeepLink", visit.visitable_type
    assert_equal "https://example.com/app", visit.visitable.destination_url
  end

  test "two clicks from the same visitor on the same day share a visitor_hash" do
    link = links(:one)
    morning = Time.utc(2026, 5, 17, 1, 0, 0)
    evening = Time.utc(2026, 5, 17, 23, 0, 0)

    RecordVisitJob.perform_now(
      visitable: link,
      ip_address: "192.0.2.10",
      user_agent: "RecordVisitJob test/1.0",
      referer: nil,
      timestamp: morning
    )
    RecordVisitJob.perform_now(
      visitable: link,
      ip_address: "192.0.2.10",
      user_agent: "RecordVisitJob test/1.0",
      referer: nil,
      timestamp: evening
    )

    hashes = Visit.where(visitable_type: "Link", visitable_id: link.id, ip_address: "192.0.2.10").pluck(:visitor_hash)
    assert_equal 1, hashes.uniq.length
  end

  test "is discarded when the visitable is deleted between enqueue and perform" do
    link = links(:one)
    RecordVisitJob.perform_later(
      visitable: link,
      ip_address: "192.0.2.10",
      user_agent: "RecordVisitJob test/1.0",
      referer: nil,
      timestamp: Time.current
    )
    link.destroy

    # The GlobalID can no longer be deserialized; discard_on should drop the job
    # cleanly rather than raising or recording a visit.
    assert_no_difference "Visit.count" do
      perform_enqueued_jobs(only: RecordVisitJob)
    end
  end
end
