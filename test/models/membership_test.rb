require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "membership requires user" do
    membership = Membership.new(workspace: workspaces(:one), role: :member)
    assert_not membership.valid?
    assert_includes membership.errors[:user], "must exist"
  end

  test "membership requires workspace" do
    membership = Membership.new(user: users(:one), role: :member)
    assert_not membership.valid?
    assert_includes membership.errors[:workspace], "must exist"
  end

  test "membership requires role" do
    membership = Membership.new(user: users(:one), workspace: workspaces(:one))
    membership.role = nil
    assert_not membership.valid?
    assert_includes membership.errors[:role], "can't be blank"
  end

  test "user can only have one membership per workspace" do
    # User one already has a membership in workspace one (from fixtures)
    duplicate = Membership.new(user: users(:one), workspace: workspaces(:one), role: :member)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "is already a member of this workspace"
  end

  test "user can have memberships in multiple workspaces" do
    new_workspace = Workspace.create!(name: "New Workspace", user: users(:one))
    # The workspace creation creates an admin membership automatically
    assert_equal 1, new_workspace.memberships.count
    assert new_workspace.memberships.first.admin?
  end

  test "role enum values" do
    membership = memberships(:one_admin)
    assert membership.admin?

    membership.role = :member
    assert membership.member?
  end

  test "admins scope returns only admins" do
    workspace = workspaces(:one)
    admins = workspace.memberships.admins
    assert admins.all?(&:admin?)
  end
end
