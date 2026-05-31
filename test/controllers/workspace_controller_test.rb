require "test_helper"

class WorkspaceControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:one)
    @admin = users(:one) # User one is admin of workspace one (from fixtures)
    @member = users(:two) # User two is a member of workspace one (from fixtures)
  end

  # Authentication tests
  test "should redirect to login when not authenticated" do
    get workspace_path(@workspace)
    assert_redirected_to new_session_path
  end

  # Authorization tests for show
  test "admin can view workspace" do
    sign_in_as(@admin)
    get workspace_path(@workspace)
    assert_response :success
  end

  test "member can view workspace" do
    sign_in_as(@member)
    get workspace_path(@workspace)
    assert_response :success
  end

  test "non-member cannot view workspace" do
    non_member = User.create!(email: "nonmember@example.com", password: "password123")
    sign_in_as(non_member)

    get workspace_path(@workspace)
    assert_redirected_to dashboard_path
    assert_equal "Workspace not found", flash[:notice]
  end

  # Authorization tests for edit
  test "admin can access edit page" do
    sign_in_as(@admin)
    get edit_workspace_path(@workspace)
    assert_response :success
  end

  test "member cannot access edit page" do
    sign_in_as(@member)
    get edit_workspace_path(@workspace)
    assert_redirected_to dashboard_path
    assert_equal "You need admin access to perform this action", flash[:alert]
  end

  # Authorization tests for update
  test "admin can update workspace" do
    sign_in_as(@admin)
    patch workspace_path(@workspace), params: { workspace: { name: "Updated Name" } }
    assert_redirected_to workspace_path(@workspace)

    @workspace.reload
    assert_equal "Updated Name", @workspace.name
  end

  test "member cannot update workspace" do
    sign_in_as(@member)
    original_name = @workspace.name

    patch workspace_path(@workspace), params: { workspace: { name: "Should Not Update" } }
    assert_redirected_to dashboard_path

    @workspace.reload
    assert_equal original_name, @workspace.name
  end

  private

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "password123" }
  end
end
