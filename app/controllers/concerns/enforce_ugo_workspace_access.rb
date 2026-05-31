# Ensures workspaces on the managed ugo.cr deployment past trial without a subscription
# cannot use the product, except billing and checkout flows. Self-hosted (dedicated) workspaces are unaffected.
#
# Include in workspace-scoped controllers and add the before_action AFTER
# load_workspace and authorize_workspace_member! so @workspace is available:
#
#   include EnforceUgoWorkspaceAccess
#   before_action :load_workspace
#   before_action :authorize_workspace_member!
#   before_action :ensure_ugo_workspace_active!
#
module EnforceUgoWorkspaceAccess
  extend ActiveSupport::Concern

  private

  def ensure_ugo_workspace_active!
    return unless @workspace.present?
    return if billing_or_checkout_action?
    return unless @workspace.ugo_access_blocked?

    message =
      if workspace_admin?
        "Your trial has ended. Subscribe to restore access to this workspace."
      else
        "This workspace requires an active subscription. Ask a workspace admin to subscribe."
      end

    respond_to do |format|
      format.html { redirect_to ugo_workspace_blocked_redirect_path, alert: message, status: :see_other }
      format.turbo_stream do
        flash[:alert] = message
        redirect_to ugo_workspace_blocked_redirect_path, status: :see_other
      end
    end
  end

  def billing_or_checkout_action?
    %w[billing checkout].include?(controller_name)
  end

  def ugo_workspace_blocked_redirect_path
    return dashboard_path unless workspace_admin?
    workspace_billing_path(@workspace)
  end
end
