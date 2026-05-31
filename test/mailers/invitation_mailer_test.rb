require "test_helper"

class InvitationMailerTest < ActionMailer::TestCase
  test "invite_email" do
    invitation = invitations(:pending_invitation)

    email = InvitationMailer.with(invitation: invitation).invite_email

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "no-reply@fdo.cr" ], email.from
    assert_equal [ invitation.email ], email.to
    assert_equal "You've been invited to join #{invitation.workspace.name} on ugo.cr", email.subject

    # Check HTML part
    assert_match invitation.workspace.name, email.html_part.body.to_s
    assert_match invitation.invited_by.email, email.html_part.body.to_s
    assert_match invitation.role, email.html_part.body.to_s

    # Check text part
    assert_match invitation.workspace.name, email.text_part.body.to_s
    assert_match invitation.invited_by.email, email.text_part.body.to_s
    assert_match invitation.role, email.text_part.body.to_s
  end
end
