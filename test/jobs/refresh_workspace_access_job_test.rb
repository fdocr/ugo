require "test_helper"

class RefreshWorkspaceAccessJobTest < ActiveJob::TestCase
  setup do
    setup_app_config_as_main_app!
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
end
