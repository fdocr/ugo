class OnboardingMailer < ApplicationMailer
  def onboarding_email
    @user = params[:user]
    @workspace = params[:workspace]
    @login_url = new_session_url

    mail(
      to: @user.email,
      subject: "Welcome to ugo.cr"
    )
  end
end
