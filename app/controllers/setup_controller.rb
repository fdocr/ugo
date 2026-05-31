class SetupController < ApplicationController
  allow_unauthenticated_access
  layout "application"

  before_action :ensure_setup_needed
  before_action -> { @hide_nav = true }

  def new
    config = AppConfig.shared
    config.update!(setup_code: SecureRandom.hex(16)) if config.setup_code.blank?
    @setup_code = config.setup_code

    Rails.logger.info "-"*20
    Rails.logger.info "SETUP CODE: #{@setup_code}"
    Rails.logger.info "-"*20
  end

  def create
    if params[:setup_code] != AppConfig.shared.setup_code
      redirect_to setup_path, alert: "Invalid setup code. Check your server logs for the correct code."
      return
    end

    # Save application settings
    config_attrs = {
      app_name: params[:app_name].presence || "My ugo",
      app_domain: params[:app_domain]
    }

    # Save SMTP settings (optional)
    if params[:smtp_address].present?
      config_attrs.merge!(
        smtp_address: params[:smtp_address],
        smtp_port: params[:smtp_port].to_i,
        smtp_username: params[:smtp_username],
        smtp_password: params[:smtp_password],
        smtp_from_email: params[:smtp_from_email].presence || "noreply@#{params[:app_domain]}"
      )
    end

    AppConfig.shared.update!(config_attrs)

    # Create admin user + workspace
    user = User.new(
      email: params[:admin_email],
      password: params[:admin_password],
      password_confirmation: params[:admin_password_confirmation],
      site_admin: true
    )

    ActiveRecord::Base.transaction do
      user.save!
      Workspace.create!(user: user, name: "Default", plan: :dedicated)
    end

    AppConfig.shared.update!(setup_completed: true)
    AppConfig.configure_smtp! if Rails.env.production?

    start_new_session_for(user)
    redirect_to dashboard_path, notice: "Setup completed successfully!"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to setup_path, alert: "Setup failed: #{e.message}"
  end

  private

  def ensure_setup_needed
    redirect_to root_path if AppConfig.shared.setup_completed
  end
end
