class MembershipsController < ApplicationController
  include EnforceUgoWorkspaceAccess

  before_action :load_workspace
  before_action :authorize_workspace_admin!
  before_action :ensure_ugo_workspace_active!
  before_action :load_membership, only: [ :destroy ]

  def destroy
    # Prevent removing yourself if you're the last admin
    if @membership.admin? && @workspace.memberships.admins.count == 1
      flash.now[:alert] = "Cannot remove the last admin from the workspace"
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream_flash }
        format.html { redirect_to workspace_path(@workspace) }
      end
      return
    end

    # Prevent removing yourself
    if @membership.user == Current.user
      flash.now[:alert] = "You cannot remove yourself from the workspace"
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream_flash }
        format.html { redirect_to workspace_path(@workspace) }
      end
      return
    end

    user_email = @membership.user.email
    @membership.destroy
    flash.now[:notice] = "#{user_email} was removed from the workspace"

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to workspace_path(@workspace) }
    end
  end

  private

  def load_workspace
    @workspace = Current.user.workspaces.find_by(id: params[:workspace_id])
    redirect_to dashboard_path, notice: "Workspace not found" if @workspace.nil?
  end

  def load_membership
    @membership = @workspace.memberships.find_by(id: params[:id])
    redirect_to workspace_path(@workspace), alert: "Member not found" if @membership.nil?
  end

  def turbo_stream_flash
    turbo_stream.update("flash", partial: "shared/flash")
  end
end
