class AdminMailer < ApplicationMailer
  def user_created(user, password)
    @user = user
    @password = password
    @app_name = AppConfig.shared.app_name
    @login_url = new_session_url(host: AppConfig.shared.app_domain.presence || "localhost")

    mail(to: user.email, subject: "Your #{@app_name} account has been created")
  end
end
