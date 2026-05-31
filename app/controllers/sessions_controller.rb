class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  before_action :enforce_unauthenticated_access, only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    user = User.find_by(email: params[:email])

    if user&.banned?
      redirect_to new_session_path, alert: "Your account has been suspended. Please contact fernando@fdo.cr if you want your ban to be reviewed."
      return
    end

    if user&.authenticate(params[:password])
      user.logged_in!
      start_new_session_for(user)
      redirect_to after_authentication_url, notice: "Successfully signed in"
    else
      redirect_to new_session_path, alert: "Invalid email or password"
    end
  end

  def destroy
    terminate_session
    flash[:notice] = "Successfully signed out"
    redirect_to root_path
  end

  private

  def enforce_unauthenticated_access
    redirect_to dashboard_path if authenticated?
  end
end
