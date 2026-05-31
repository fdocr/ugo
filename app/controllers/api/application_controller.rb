class Api::ApplicationController < ActionController::Base
  before_action :authenticate_request
  rate_limit to: 60, within: 1.minute,
    by: -> { request.headers["X-Api-Key"].to_s },
    with: -> { render json: { error: "Rate limit exceeded" }, status: :too_many_requests }

  private

  def api_key
    @api_key ||= request.headers["X-Api-Key"]
  end

  def admin_api_key?
    ActiveSupport::SecurityUtils.secure_compare(@api_key.to_s, AppConfig.shared.admin_api_key.to_s)
  end

  def authenticate_request
    @current_workspace = Workspace.find_by(api_token: api_key) if api_key.present?
    unless @current_workspace || admin_api_key?
      render json: { error: "Not Authorized" }, status: 401
    end
  end
end
