class InvitationMailer < ApplicationMailer
  def invite_email
    @invitation = params[:invitation]
    @workspace = @invitation.workspace
    @invited_by = @invitation.invited_by
    @sign_in_url = new_session_url
    @sign_up_url = sign_up_url

    mail(
      to: @invitation.email,
      subject: "You've been invited to join #{@workspace.name} on ugo.cr"
    )
  end
end
