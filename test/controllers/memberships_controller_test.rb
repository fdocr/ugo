require "test_helper"

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:one)
    @member_user = users(:two)
    @workspace = workspaces(:one)
    @member_membership = memberships(:two_member_of_one)
  end

  # Authentication tests
  test "should redirect to login when not authenticated" do
    delete workspace_membership_path(@workspace, @member_membership)
    assert_redirected_to new_session_path
  end

  # Authorization tests - Admin user
  test "admin can remove member" do
    sign_in @admin_user

    assert_difference "Membership.count", -1 do
      delete workspace_membership_path(@workspace, @member_membership),
        headers: { "Accept" => "text/html" }
    end

    assert_redirected_to workspace_path(@workspace)
    assert_equal "#{@member_user.email} was removed from the workspace", flash[:notice]
  end

  test "admin can remove member with turbo stream" do
    sign_in @admin_user

    email = @member_user.email
    assert_difference "Membership.count", -1 do
      delete workspace_membership_path(@workspace, @member_membership),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "turbo-stream", response.body
  end

  test "admin cannot remove themselves" do
    # Create another admin so "last admin" check doesn't trigger first
    other_admin = User.create!(email: "other_admin2@example.com", password: "password123")
    @workspace.memberships.create!(user: other_admin, role: :admin)

    sign_in @admin_user
    admin_membership = memberships(:one_admin)

    assert_no_difference "Membership.count" do
      delete workspace_membership_path(@workspace, admin_membership),
        headers: { "Accept" => "text/html" }
    end

    assert_redirected_to workspace_path(@workspace)
    assert_equal "You cannot remove yourself from the workspace", flash[:alert]
  end

  test "admin cannot remove last admin" do
    sign_in @admin_user

    # The admin_membership is the only admin
    admin_membership = memberships(:one_admin)

    # Verify this is the only admin
    assert_equal 1, @workspace.memberships.admins.count

    assert_no_difference "Membership.count" do
      delete workspace_membership_path(@workspace, admin_membership),
        headers: { "Accept" => "text/html" }
    end

    assert_redirected_to workspace_path(@workspace)
    # "Last admin" check triggers before "remove yourself" check
    assert_equal "Cannot remove the last admin from the workspace", flash[:alert]
  end

  test "cannot remove last admin even if different user" do
    # Create another admin user
    other_admin = User.create!(email: "other_admin@example.com", password: "password123")
    other_admin_membership = @workspace.memberships.create!(user: other_admin, role: :admin)

    sign_in other_admin

    # Now there are 2 admins, the original one can be removed
    original_admin_membership = memberships(:one_admin)

    assert_difference "Membership.count", -1 do
      delete workspace_membership_path(@workspace, original_admin_membership),
        headers: { "Accept" => "text/html" }
    end

    assert_redirected_to workspace_path(@workspace)
    assert_equal "#{@admin_user.email} was removed from the workspace", flash[:notice]
  end

  # Authorization tests - Member user (non-admin)
  test "member cannot remove other members" do
    sign_in @member_user

    # Try to remove the admin
    admin_membership = memberships(:one_admin)

    assert_no_difference "Membership.count" do
      delete workspace_membership_path(@workspace, admin_membership)
    end

    assert_redirected_to dashboard_path
    assert_equal "You need admin access to perform this action", flash[:alert]
  end

  # Non-member tests
  test "non-member cannot remove members" do
    other_user = User.create!(email: "other@example.com", password: "password123")
    sign_in other_user

    assert_no_difference "Membership.count" do
      delete workspace_membership_path(@workspace, @member_membership)
    end

    assert_redirected_to dashboard_path
  end

  private

  def sign_in(user)
    post session_path, params: { email: user.email, password: "password123" }
  end
end
