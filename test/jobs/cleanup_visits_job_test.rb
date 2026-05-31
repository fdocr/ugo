require "test_helper"

class CleanupVisitsJobTest < ActiveJob::TestCase
  test "cleans up old visits for free workspaces" do
    user = users(:one)
    free_workspace = Workspace.create!(name: "Free Test", user: user, plan: "free")
    link = Link.create!(slug: "test-link", workspace: free_workspace, url: "https://example.com")

    # Create visits: one old (should be deleted) and one recent (should remain)
    old_visit = Visit.create!(
      visitable: link,
      ip_address: "192.168.1.1",
      user_agent: "Test Browser",
      timestamp: 2.months.ago
    )
    recent_visit = Visit.create!(
      visitable: link,
      ip_address: "192.168.1.2",
      user_agent: "Test Browser",
      timestamp: 2.weeks.ago
    )

    CleanupVisitsJob.perform_now

    assert_not Visit.exists?(old_visit.id), "Old visit should be deleted"
    assert Visit.exists?(recent_visit.id), "Recent visit should remain"
  end

  test "cleans up old visits for basic workspaces" do
    user = users(:one)
    basic_workspace = Workspace.create!(name: "Basic Test", user: user, plan: "basic")
    link = Link.create!(slug: "basic-link", workspace: basic_workspace, url: "https://example.com")

    # Create visits: one very old (should be deleted) and one moderately old (should remain)
    very_old_visit = Visit.create!(
      visitable: link,
      ip_address: "192.168.1.1",
      user_agent: "Test Browser",
      timestamp: 4.months.ago
    )
    moderately_old_visit = Visit.create!(
      visitable: link,
      ip_address: "192.168.1.2",
      user_agent: "Test Browser",
      timestamp: 2.months.ago
    )

    CleanupVisitsJob.perform_now

    assert_not Visit.exists?(very_old_visit.id), "Very old visit should be deleted"
    assert Visit.exists?(moderately_old_visit.id), "Moderately old visit should remain"
  end

  test "does not affect dedicated workspaces" do
    user = users(:one)
    dedicated_workspace = Workspace.create!(name: "Dedicated Test", user: user, plan: "dedicated")
    link = Link.create!(slug: "dedicated-link", workspace: dedicated_workspace, url: "https://example.com")

    # Create a very old visit that should not be deleted for dedicated plans
    old_visit = Visit.create!(
      visitable: link,
      ip_address: "192.168.1.1",
      user_agent: "Test Browser",
      timestamp: 6.months.ago
    )

    CleanupVisitsJob.perform_now

    assert Visit.exists?(old_visit.id), "Visit in dedicated workspace should remain"
  end

  test "handles workspaces with no visits gracefully" do
    user = users(:one)
    empty_workspace = Workspace.create!(name: "Empty Test", user: user, plan: "free")
    Link.create!(slug: "empty-link", workspace: empty_workspace, url: "https://example.com")

    assert_nothing_raised do
      CleanupVisitsJob.perform_now
    end
  end

  test "logs cleanup activity" do
    user = users(:one)
    free_workspace = Workspace.create!(name: "Logging Test", user: user, plan: "free")
    link = Link.create!(slug: "logging-link", workspace: free_workspace, url: "https://example.com")

    Visit.create!(
      visitable: link,
      ip_address: "192.168.1.1",
      user_agent: "Test Browser",
      timestamp: 2.months.ago
    )

    # Capture log output
    logs = []
    original_logger = Rails.logger
    Rails.logger = Logger.new(StringIO.new).tap do |logger|
      logger.define_singleton_method(:info) do |message|
        logs << message
      end
    end

    CleanupVisitsJob.perform_now

    assert logs.any? { |log| log.include?("CleanupVisitsJob") }, "Should log cleanup activity"
  ensure
    Rails.logger = original_logger
  end
end
