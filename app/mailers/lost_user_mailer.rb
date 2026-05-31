class LostUserMailer < ApplicationMailer
  default from: "no-reply@fdo.cr"

  def user_deleted_notification(user)
    @user = user
    @sessions = user.sessions.all

    mail(
      to: "fernando@fdo.cr",
      subject: "Lost ugo.cr user: #{user.email}"
    )
  end
end
