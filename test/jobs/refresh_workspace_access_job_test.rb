require "test_helper"

class RefreshWorkspaceAccessJobTest < ActiveJob::TestCase
  setup do
    setup_app_config_as_main_app!
    Flipper.disable(:open_beta)
  end

  teardown do
    Flipper.disable(:open_beta)
  end

  test "marks workspaces with newly-expired trials as blocked" do
    user = users(:one)
    workspace = Workspace.create!(name: "Trial Just Expired", user: user, plan: :free)
    workspace.update_column(:trial_ends_at, 5.minutes.ago)
    assert_nil workspace.reload.access_blocked_at, "Direct column write must not auto-recompute"

    RefreshWorkspaceAccessJob.perform_now

    assert_predicate workspace.reload.access_blocked_at, :present?
  end

  test "clears the flag when a previously blocked workspace becomes payable again" do
    user = users(:one)
    workspace = Workspace.create!(name: "Recovered", user: user, plan: :free)
    workspace.update!(trial_ends_at: 1.day.ago)
    assert_predicate workspace.reload.access_blocked_at, :present?

    workspace.update!(plan: :basic)
    workspace.create_subscription!(status: :active, amount_cents: 900, currency: "USD")
    workspace.update_column(:access_blocked_at, 1.minute.ago)

    RefreshWorkspaceAccessJob.perform_now

    assert_nil workspace.reload.access_blocked_at
  end

  test "no-ops on self-hosted installs" do
    setup_app_config_as_self_hosted!

    user = users(:one)
    workspace = Workspace.create!(name: "Dedicated SH", user: user, plan: :dedicated)
    workspace.update_column(:access_blocked_at, Time.current)

    RefreshWorkspaceAccessJob.perform_now

    assert_predicate workspace.reload.access_blocked_at, :present?,
      "Self-hosted should be a no-op; nothing should mutate the column from the sweeper"
  end

  test "extends expired trial for active users during open beta" do
    Flipper.enable(:open_beta)

    user = users(:one)
    user.update!(last_login_at: 1.day.ago)
    workspace = Workspace.create!(name: "Open Beta Active", user: user, plan: :free)
    workspace.update_column(:trial_ends_at, 5.minutes.ago)
    workspace.update_column(:access_blocked_at, 1.minute.ago)

    RefreshWorkspaceAccessJob.perform_now

    workspace.reload
    assert workspace.trial_ends_at > Time.current
    assert_nil workspace.access_blocked_at
  end

  test "blocks expired trial for inactive users during open beta" do
    Flipper.enable(:open_beta)

    user = users(:two)
    user.update!(last_login_at: 60.days.ago)
    workspace = Workspace.create!(name: "Open Beta Inactive", user: user, plan: :free)
    workspace.update_column(:trial_ends_at, 5.minutes.ago)

    RefreshWorkspaceAccessJob.perform_now

    assert_predicate workspace.reload.access_blocked_at, :present?
  end

  test "extends expired trial when workspace has recent visits during open beta" do
    Flipper.enable(:open_beta)

    user = users(:two)
    user.update!(last_login_at: nil)
    workspace = Workspace.create!(name: "Open Beta Visits", user: user, plan: :free)
    link = Link.create!(slug: "open-beta-visits", workspace: workspace, url: "https://example.com")
    Visit.create!(
      visitable: link,
      ip_address: "127.0.0.1",
      user_agent: "Test",
      timestamp: 2.days.ago
    )
    workspace.update_column(:trial_ends_at, 5.minutes.ago)

    RefreshWorkspaceAccessJob.perform_now

    workspace.reload
    assert workspace.trial_ends_at > Time.current
    assert_nil workspace.access_blocked_at
  end
end
