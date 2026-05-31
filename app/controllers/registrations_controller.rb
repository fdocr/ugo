class RegistrationsController < ApplicationController
  before_action :redirect_if_authenticated, only: [ :new, :create ]
  before_action :require_authentication, only: [ :destroy ]
  before_action :ensure_registration_enabled, only: [ :new, :create ]
  allow_unauthenticated_access only: [ :new, :create ]

  def new
  end

  def create
    return if redirect_if_turnstile_invalid(sign_up_path)

    @user = User.new(email: params[:email], password: params[:password], password_confirmation: params[:password_confirmation])

    ActiveRecord::Base.transaction do
      @user.save!
      @workspace = Workspace.create!(user: @user, name: "Default")
    end

    start_new_session_for(@user)
    redirect_to dashboard_path, notice: "Welcome! Your Basic plan trial is active — subscribe anytime to keep access after it ends."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to sign_up_path, alert: "Failed to create account: #{e.message}"
  end

  def destroy
    user = Current.user

    LostUserMailer.user_deleted_notification(user).deliver_now
    terminate_session

    if user.destroy
      redirect_to root_path, notice: "Your account has been permanently deleted"
    else
      redirect_to dashboard_path, alert: "Could not delete account"
    end
  end

  private

  def ensure_registration_enabled
    if self_hosted?
      redirect_to root_path, alert: "Open registration is disabled. Contact your administrator."
    end
  end
end
