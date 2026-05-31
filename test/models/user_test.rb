require "test_helper"

class UserTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "user requires email" do
    user = User.new(password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "user requires unique email" do
    existing_user = users(:one)
    user = User.new(email: existing_user.email, password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "user requires password" do
    user = User.new(email: "test@example.com")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "email is normalized to lowercase" do
    user = User.create!(email: "TEST@EXAMPLE.COM", password: "password123")
    assert_equal "test@example.com", user.email
  end

  test "email is stripped of whitespace" do
    user = User.create!(email: "  test@example.com  ", password: "password123")
    assert_equal "test@example.com", user.email
  end

  test "site_admin? returns false by default" do
    user = User.create!(email: "newuser@example.com", password: "password123")
    assert_not user.site_admin?
  end

  test "site_admin? returns true when site_admin is set" do
    user = User.create!(email: "siteadmin@example.com", password: "password123", site_admin: true)
    assert user.site_admin?
  end


  test "logged_in! updates last_login_at" do
    user = users(:one)
    assert_nil user.last_login_at

    user.logged_in!

    assert_not_nil user.last_login_at
    assert_in_delta Time.current, user.last_login_at, 1.second
  end

  test "user has many memberships" do
    user = users(:one)
    assert_respond_to user, :memberships
    assert user.memberships.count > 0
  end

  test "user has many member_workspaces through memberships" do
    user = users(:one)
    assert_respond_to user, :member_workspaces
    assert user.member_workspaces.count > 0
  end

  test "workspaces is alias for member_workspaces" do
    user = users(:one)
    assert_equal user.member_workspaces.to_a, user.workspaces.to_a
  end

  test "pending_invitations returns invitations for user email" do
    # Create a pending invitation for user one's email
    invitation = Invitation.create!(
      workspace: workspaces(:two),
      email: users(:one).email,
      role: :member,
      invited_by: users(:two)
    )

    user = users(:one)
    assert_includes user.pending_invitations, invitation
  end

  test "destroying user destroys memberships" do
    user = User.create!(email: "todelete@example.com", password: "password123")
    workspace = Workspace.create!(name: "Test", user: user)

    assert_difference "Membership.count", -1 do
      user.destroy
    end
  end

  # Ban functionality tests
  test "banned? returns false by default" do
    user = User.create!(email: "notbanned@example.com", password: "password123")
    assert_not user.banned?
  end

  test "banned? returns true when banned_at is set" do
    user = User.create!(email: "banned@example.com", password: "password123", banned_at: Time.current)
    assert user.banned?
  end

  test "ban! sets banned_at timestamp" do
    user = User.create!(email: "toban@example.com", password: "password123")
    assert_nil user.banned_at

    user.ban!

    assert_not_nil user.banned_at
    assert user.banned?
  end

  test "ban! destroys all user sessions" do
    user = User.create!(email: "toban@example.com", password: "password123")
    Session.create!(user: user, ip_address: "127.0.0.1", user_agent: "Test")
    Session.create!(user: user, ip_address: "127.0.0.1", user_agent: "Test2")
    assert_equal 2, user.sessions.count

    user.ban!

    assert_equal 0, user.sessions.count
  end

  test "ban! enqueues BanUserLinksJob" do
    user = User.create!(email: "toban@example.com", password: "password123")

    assert_enqueued_with(job: BanUserLinksJob, args: [ { user_id: user.id, ban: true } ]) do
      user.ban!
    end
  end

  test "unban! clears banned_at timestamp" do
    user = User.create!(email: "tounban@example.com", password: "password123", banned_at: Time.current)
    assert user.banned?

    user.unban!

    assert_nil user.banned_at
    assert_not user.banned?
  end

  test "unban! enqueues BanUserLinksJob" do
    user = User.create!(email: "tounban@example.com", password: "password123", banned_at: Time.current)

    assert_enqueued_with(job: BanUserLinksJob, args: [ { user_id: user.id, ban: false } ]) do
      user.unban!
    end
  end
end
