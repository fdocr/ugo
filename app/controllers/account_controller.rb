class AccountController < ApplicationController
  def edit_password
  end

  def update_password
    if Current.user.authenticate(params[:current_password])
      if Current.user.update(password: params[:password], password_confirmation: params[:password_confirmation])
        redirect_to dashboard_path, notice: "Password updated successfully."
      else
        redirect_to edit_account_password_path, alert: "Failed to update password: #{Current.user.errors.full_messages.join(', ')}"
      end
    else
      redirect_to edit_account_password_path, alert: "Current password is incorrect."
    end
  end

  private

  def setup_navbar
    @page_title = "Change Password"
    @back_url = dashboard_path
  end
end
