class WorkspaceController < ApplicationController
  include EnforceUgoWorkspaceAccess

  before_action :load_workspace
  before_action :authorize_workspace_member!
  before_action :ensure_ugo_workspace_active!
  before_action :authorize_workspace_admin!, only: [ :edit, :update ]
  before_action :setup_navbar

  def show
    @current_month_visits = @workspace.links.joins(:visits)
                                     .where(visits: { processed_at: Time.current.beginning_of_month..Time.current.end_of_month })
                                     .where.not(visits: { processed_at: nil })
                                     .count
    @memberships = @workspace.memberships.includes(:user).order(:role)
  end

  def edit
  end

  def update
    if @workspace.update(workspace_params)
      redirect_to workspace_path(@workspace.id), notice: "Workspace was successfully updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def workspace_params
    params.require(:workspace).permit(:name, :weekly_digest, :monthly_digest)
  end

  def load_workspace
    @workspace = Current.user.workspaces.find_by(id: params[:id])
    redirect_to dashboard_path, notice: "Workspace not found" if @workspace.nil?
  end

  def setup_navbar
    case params[:action]
    when "show"
      @page_title = "#{@workspace.name} workspace"
      @back_url = dashboard_path
    when "edit"
      @page_title = "Edit workspace"
      @back_url = workspace_path(@workspace.id)
    end
  end
end
