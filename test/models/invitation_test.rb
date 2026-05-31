require "test_helper"

class InvitationTest < ActiveSupport::TestCase
  test "invitation requires workspace" do
    invitation = Invitation.new(
      email: "test@example.com",
      role: :member,
      invited_by: users(:one)
    )
    assert_not invitation.valid?
    assert_includes invitation.errors[:workspace], "must exist"
  end

  test "invitation requires email" do
    invitation = Invitation.new(
      workspace: workspaces(:one),
      role: :member,
      invited_by: users(:one)
    )
    assert_not invitation.valid?
    assert_includes invitation.errors[:email], "can't be blank"
  end

  test "invitation requires valid email format" do
    invitation = Invitation.new(
      workspace: workspaces(:one),
      email: "invalid-email",
      role: :member,
      invited_by: users(:one)
    )
    assert_not invitation.valid?
    assert_includes invitation.errors[:email], "is invalid"
  end

  test "invitation requires invited_by" do
    invitation = Invitation.new(
      workspace: workspaces(:one),
      email: "test@example.com",
      role: :member
    )
    assert_not invitation.valid?
    assert_includes invitation.errors[:invited_by], "must exist"
  end

  test "invitation generates token automatically" do
    invitation = Invitation.new(
      workspace: workspaces(:one),
      email: "newuser@example.com",
      role: :member,
      invited_by: users(:one)
    )
    assert_nil invitation.token
    invitation.valid?
    assert_not_nil invitation.token
    assert invitation.token.length >= 32
  end

  test "invitation sets expiration automatically" do
    invitation = Invitation.new(
      workspace: workspaces(:one),
      email: "newuser@example.com",
      role: :member,
      invited_by: users(:one)
    )
    assert_nil invitation.expires_at
    invitation.valid?
    assert_not_nil invitation.expires_at
    assert invitation.expires_at > Time.current
  end

  test "invitation normalizes email to lowercase" do
    invitation = Invitation.create!(
      workspace: workspaces(:one),
      email: "TEST@EXAMPLE.COM",
      role: :member,
      invited_by: users(:one)
    )
    assert_equal "test@example.com", invitation.email
  end

  test "pending? returns true for valid pending invitation" do
    invitation = invitations(:pending_invitation)
    assert invitation.pending?
  end

  test "pending? returns false for expired invitation" do
    invitation = invitations(:expired_invitation)
    assert_not invitation.pending?
  end

  test "pending? returns false for accepted invitation" do
    invitation = invitations(:accepted_invitation)
    assert_not invitation.pending?
  end

  test "expired? returns true for expired invitation" do
    invitation = invitations(:expired_invitation)
    assert invitation.expired?
  end

  test "expired? returns false for pending invitation" do
    invitation = invitations(:pending_invitation)
    assert_not invitation.expired?
  end

  test "accepted? returns true for accepted invitation" do
    invitation = invitations(:accepted_invitation)
    assert invitation.accepted?
  end

  test "accepted? returns false for pending invitation" do
    invitation = invitations(:pending_invitation)
    assert_not invitation.accepted?
  end

  test "accept! creates membership and marks invitation as accepted" do
    invitation = invitations(:pending_invitation)
    new_user = User.create!(email: "invited@example.com", password: "password123")

    assert_difference "Membership.count", 1 do
      invitation.accept!(new_user)
    end

    invitation.reload
    assert invitation.accepted?
    assert_not_nil invitation.accepted_at

    membership = invitation.workspace.membership_for(new_user)
    assert_not_nil membership
    assert_equal invitation.role, membership.role
  end

  test "pending scope returns only pending invitations" do
    pending = Invitation.pending
    assert pending.all?(&:pending?)
  end

  test "expired scope returns only expired invitations" do
    expired = Invitation.expired
    assert expired.all?(&:expired?)
  end

  test "role enum values" do
    invitation = invitations(:pending_invitation)
    assert invitation.member?

    invitation.role = :admin
    assert invitation.admin?
  end
end
