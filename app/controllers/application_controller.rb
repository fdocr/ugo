class ApplicationController < ActionController::Base
  include Authentication
  include WorkspaceAuthorization

  before_action :redirect_to_setup_if_needed

  # When a site admin has pasted analytics snippets into admin_scripts,
  # relax script-src so those third-party tags actually load.
  before_action :relax_csp_for_admin_scripts

  helper_method :self_hosted?, :turnstile_required?

  private

  def self_hosted?
    AppConfig.self_hosted?
  end

  def current_user
    Current.user if authenticated?
  end

  def authenticate_site_admin!
    redirect_to "/", alert: "You are not authorized to access this page" unless current_user&.site_admin?
  end

  # Backward compatibility alias
  alias_method :authenticate_admin!, :authenticate_site_admin!

  def redirect_if_authenticated
    redirect_to root_path, notice: "You are already signed in" if authenticated?
  end

  def turnstile_required?
    AppConfig.main_app? && ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"].present?
  end

  def redirect_if_turnstile_invalid(path)
    return false unless turnstile_required?
    return false if valid_turnstile?

    redirect_to path, alert: "Verification failed. Please try again."
    true
  end

  def relax_csp_for_admin_scripts
    return unless AppConfig.shared.admin_scripts.present?

    request.content_security_policy.script_src :self, :unsafe_inline, :https
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    nil
  end

  def redirect_to_setup_if_needed
    return if controller_name == "setup"
    return if controller_name == "health"
    redirect_to setup_path unless AppConfig.shared.setup_completed
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    # DB not yet migrated
  end
end
