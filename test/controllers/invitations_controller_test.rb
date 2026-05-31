require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:one)
    @member_user = users(:two)
    @workspace = workspaces(:one)
    @invitation = invitations(:pending_invitation)
  end

  # Authentication tests
  test "should redirect to login when not authenticated for create" do
    post workspace_invitations_path(@workspace), params: { invitation: { email: "new@example.com", role: "member" } }
    assert_redirected_to new_session_path
  end

  test "should redirect to login when not authenticated for destroy" do
    delete workspace_invitation_path(@workspace, @invitation)
    assert_redirected_to new_session_path
  end

  # Authorization tests - Admin user
  test "admin can create invitation" do
    sign_in @admin_user

    assert_difference "Invitation.count", 1 do
      assert_enqueued_emails 1 do
        post workspace_invitations_path(@workspace),
          params: { invitation: { email: "newuser@example.com", role: "member" } },
          headers: { "Accept" => "text/html" }
      end
    end

    assert_redirected_to workspace_path(@workspace)
    assert_equal "Invitation sent to newuser@example.com", flash[:notice]
  end

  test "admin can create invitation with turbo stream" do
    sign_in @admin_user

    assert_difference "Invitation.count", 1 do
      post workspace_invitations_path(@workspace),
        params: { invitation: { email: "newuser@example.com", role: "member" } },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "turbo-stream", response.body
  end

  test "admin can cancel invitation" do
    sign_in @admin_user

    assert_difference "Invitation.count", -1 do
      delete workspace_invitation_path(@workspace, @invitation),
        headers: { "Accept" => "text/html" }
    end

    assert_redirected_to workspace_path(@workspace)
    assert_equal "Invitation to #{@invitation.email} was cancelled", flash[:notice]
  end

  test "admin can cancel invitation with turbo stream" do
    sign_in @admin_user

    email = @invitation.email
    assert_difference "Invitation.count", -1 do
      delete workspace_invitation_path(@workspace, @invitation),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "turbo-stream", response.body
  end

  # Authorization tests - Member user (non-admin)
  test "member cannot create invitation" do
    sign_in @member_user

    assert_no_difference "Invitation.count" do
      post workspace_invitations_path(@workspace),
        params: { invitation: { email: "newuser@example.com", role: "member" } }
    end

    assert_redirected_to dashboard_path
    assert_equal "You need admin access to perform this action", flash[:alert]
  end

  test "member cannot cancel invitation" do
    sign_in @member_user

    assert_no_difference "Invitation.count" do
      delete workspace_invitation_path(@workspace, @invitation)
    end

    assert_redirected_to dashboard_path
    assert_equal "You need admin access to perform this action", flash[:alert]
  end

  # Non-member tests
  test "non-member cannot create invitation" do
    other_user = User.create!(email: "other@example.com", password: "password123")
    sign_in other_user

    assert_no_difference "Invitation.count" do
      post workspace_invitations_path(@workspace),
        params: { invitation: { email: "newuser@example.com", role: "member" } }
    end

    assert_redirected_to dashboard_path
  end

  # Validation tests
  test "create fails with invalid email" do
    sign_in @admin_user

    assert_no_difference "Invitation.count" do
      post workspace_invitations_path(@workspace),
        params: { invitation: { email: "", role: "member" } },
        headers: { "Accept" => "text/html" }
    end

    assert_redirected_to workspace_path(@workspace)
    assert_match "Email can't be blank", flash[:alert]
  end

  test "create fails with duplicate pending invitation" do
    sign_in @admin_user

    assert_no_difference "Invitation.count" do
      post workspace_invitations_path(@workspace),
        params: { invitation: { email: @invitation.email, role: "member" } },
        headers: { "Accept" => "text/html" }
    end

    assert_redirected_to workspace_path(@workspace)
    assert_match "already been invited", flash[:alert]
  end

  # Respond action tests - accepting invitations
  test "user can accept invitation" do
    invited_user = User.create!(email: @invitation.email, password: "password123")
    sign_in invited_user

    assert_difference "Membership.count", 1 do
      patch respond_invitation_path(@invitation),
        params: { response: "accept" },
        headers: { "Accept" => "text/html" }
    end

    assert_redirected_to dashboard_path
    assert_equal "You've joined #{@workspace.name}", flash[:notice]

    # Verify membership was created with correct role
    membership = invited_user.memberships.find_by(workspace: @workspace)
    assert_not_nil membership
    assert_equal @invitation.role, membership.role
  end

  test "user can accept invitation with turbo stream" do
    invited_user = User.create!(email: @invitation.email, password: "password123")
    sign_in invited_user

    assert_difference "Membership.count", 1 do
      patch respond_invitation_path(@invitation),
        params: { response: "accept" },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "turbo-stream", response.body
    assert_match @workspace.name, response.body
  end

  # Respond action tests - declining invitations
  test "user can decline invitation" do
    invited_user = User.create!(email: @invitation.email, password: "password123")
    sign_in invited_user

    assert_no_difference "Membership.count" do
      patch respond_invitation_path(@invitation),
        params: { response: "decline" },
        headers: { "Accept" => "text/html" }
    end

    assert_redirected_to dashboard_path
    assert_equal "Invitation declined", flash[:notice]

    # Verify invitation was marked as processed
    @invitation.reload
    assert_not_nil @invitation.accepted_at
  end

  test "user can decline invitation with turbo stream" do
    invited_user = User.create!(email: @invitation.email, password: "password123")
    sign_in invited_user

    assert_no_difference "Membership.count" do
      patch respond_invitation_path(@invitation),
        params: { response: "decline" },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "turbo-stream", response.body
  end

  # Respond action - error cases
  test "respond fails for non-existent invitation" do
    sign_in @admin_user
    get dashboard_path # Clear flash from sign_in

    patch respond_invitation_path(id: 999999),
      params: { response: "accept" },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "not found, expired, or already processed", response.body
  end

  test "respond fails for invitation to different email" do
    sign_in @admin_user # admin's email doesn't match invitation email
    get dashboard_path # Clear flash from sign_in

    assert_no_difference "Membership.count" do
      patch respond_invitation_path(@invitation),
        params: { response: "accept" },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "not found, expired, or already processed", response.body
  end

  test "respond fails for expired invitation" do
    expired_invitation = invitations(:expired_invitation)
    invited_user = User.create!(email: expired_invitation.email, password: "password123")
    # Create a workspace so dashboard doesn't fail
    Workspace.create!(user: invited_user, name: "Test")
    sign_in invited_user
    get dashboard_path # Clear flash from sign_in

    assert_no_difference "Membership.count" do
      patch respond_invitation_path(expired_invitation),
        params: { response: "accept" },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "not found, expired, or already processed", response.body
  end

  test "respond requires authentication" do
    patch respond_invitation_path(@invitation), params: { response: "accept" }
    assert_redirected_to new_session_path
  end

  # -- Self-hosted: auto-create user --

  test "invite auto-creates user on self-hosted" do
    setup_app_config_as_self_hosted!
    sign_in @admin_user

    assert_difference "User.count", 1 do
      assert_difference "Membership.count", 1 do
        post workspace_invitations_path(@workspace),
          params: { invitation: { email: "newteam@company.com", role: "member" } },
          headers: { "Accept" => "text/html" }
      end
    end

    assert_redirected_to workspace_path(@workspace)

    user = User.find_by(email: "newteam@company.com")
    assert_not_nil user
    assert @workspace.member?(user)
  end

  test "invite auto-creates user with admin role on self-hosted" do
    setup_app_config_as_self_hosted!
    sign_in @admin_user

    assert_difference "User.count", 1 do
      post workspace_invitations_path(@workspace),
        params: { invitation: { email: "newadmin@company.com", role: "admin" } },
        headers: { "Accept" => "text/html" }
    end

    user = User.find_by(email: "newadmin@company.com")
    membership = @workspace.membership_for(user)
    assert membership.admin?, "User should be added with admin role"
  end

  test "invite sends credentials email on self-hosted" do
    setup_app_config_as_self_hosted!
    sign_in @admin_user

    assert_enqueued_emails 1 do
      post workspace_invitations_path(@workspace),
        params: { invitation: { email: "emailed@company.com", role: "member" } },
        headers: { "Accept" => "text/html" }
    end
  end

  test "invite follows normal flow for existing user on self-hosted" do
    setup_app_config_as_self_hosted!
    existing_user = User.create!(email: "existing@company.com", password: "password123")
    sign_in @admin_user

    assert_no_difference "User.count" do
      assert_difference "Invitation.count", 1 do
        post workspace_invitations_path(@workspace),
          params: { invitation: { email: "existing@company.com", role: "member" } },
          headers: { "Accept" => "text/html" }
      end
    end

    assert_redirected_to workspace_path(@workspace)
  end

  test "invite follows normal flow on main app" do
    sign_in @admin_user

    assert_no_difference "User.count" do
      assert_difference "Invitation.count", 1 do
        post workspace_invitations_path(@workspace),
          params: { invitation: { email: "normal@example.com", role: "member" } },
          headers: { "Accept" => "text/html" }
      end
    end

    assert_redirected_to workspace_path(@workspace)
  end

  private

  def sign_in(user)
    post session_path, params: { email: user.email, password: "password123" }
  end
end
