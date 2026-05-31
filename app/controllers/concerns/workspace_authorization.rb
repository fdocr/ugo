module WorkspaceAuthorization
  extend ActiveSupport::Concern

  included do
    helper_method :current_membership, :workspace_admin?
  end

  private

  def current_membership
    return @current_membership if defined?(@current_membership)
    @current_membership = @workspace&.membership_for(Current.user)
  end

  def workspace_admin?
    @workspace&.admin?(Current.user)
  end

  def authorize_workspace_member!
    return if @workspace&.member?(Current.user)
    handle_unauthorized("You don't have access to this workspace")
  end

  def authorize_workspace_admin!
    return if @workspace&.admin?(Current.user)
    handle_unauthorized("You need admin access to perform this action")
  end

  def handle_unauthorized(message = "You are not authorized to perform this action")
    respond_to do |format|
      format.html { redirect_to dashboard_path, alert: message }
      format.json { render json: { error: message }, status: :forbidden }
    end
  end
end
