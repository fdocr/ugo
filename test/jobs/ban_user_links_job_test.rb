require "test_helper"

class BanUserLinksJobTest < ActiveJob::TestCase
  test "banning sets banned_at on all user's links" do
    user = User.create!(email: "toban@example.com", password: "password123")
    workspace = Workspace.create!(name: "Test Workspace", user: user)
    link1 = Link.create!(workspace: workspace, slug: "test1", url: "https://example1.com")
    link2 = Link.create!(workspace: workspace, slug: "test2", url: "https://example2.com")

    assert_nil link1.banned_at
    assert_nil link2.banned_at

    BanUserLinksJob.perform_now(user_id: user.id, ban: true)

    link1.reload
    link2.reload
    assert_not_nil link1.banned_at
    assert_not_nil link2.banned_at
  end

  test "unbanning clears banned_at on all user's links" do
    user = User.create!(email: "tounban@example.com", password: "password123")
    workspace = Workspace.create!(name: "Test Workspace", user: user)
    link1 = Link.create!(workspace: workspace, slug: "test1", url: "https://example1.com", banned_at: Time.current)
    link2 = Link.create!(workspace: workspace, slug: "test2", url: "https://example2.com", banned_at: Time.current)

    assert_not_nil link1.banned_at
    assert_not_nil link2.banned_at

    BanUserLinksJob.perform_now(user_id: user.id, ban: false)

    link1.reload
    link2.reload
    assert_nil link1.banned_at
    assert_nil link2.banned_at
  end

  test "handles non-existent user gracefully" do
    # Should not raise an error
    assert_nothing_raised do
      BanUserLinksJob.perform_now(user_id: 999999, ban: true)
    end
  end

  test "bans links across multiple workspaces" do
    user = User.create!(email: "multiworkspace@example.com", password: "password123")
    workspace1 = Workspace.create!(name: "Workspace 1", user: user)
    workspace2 = Workspace.create!(name: "Workspace 2", user: user)
    link1 = Link.create!(workspace: workspace1, slug: "ws1link", url: "https://example1.com")
    link2 = Link.create!(workspace: workspace2, slug: "ws2link", url: "https://example2.com")

    BanUserLinksJob.perform_now(user_id: user.id, ban: true)

    link1.reload
    link2.reload
    assert_not_nil link1.banned_at
    assert_not_nil link2.banned_at
  end
end
