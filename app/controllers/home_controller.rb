class HomeController < ApplicationController
  include Pagy::Method

  allow_unauthenticated_access only: [ :index, :about, :privacy, :pricing, :self_host ]

  def index
    return unless self_hosted?

    if authenticated?
      redirect_to dashboard_path
    else
      render "home/self_hosted_index"
    end
  end

  def dashboard
  end

  def links
    @search = params[:search]
    @workspace_id = params[:workspace_id]
    @workspaces = Current.user.workspaces
    @filterable_workspaces = @workspaces.reject(&:ugo_access_blocked?)
    active_workspace_ids = @filterable_workspaces.map(&:id)

    scope = Link.includes(:workspace)
                .where(workspace_id: active_workspace_ids)
                .order(created_at: :desc)

    if @workspace_id.present?
      scope = scope.where(workspace_id: @workspace_id)
    end

    if @search.present?
      search_term = "%#{@search.downcase}%"
      scope = scope.where(
        "LOWER(links.name) LIKE ? OR LOWER(links.slug) LIKE ? OR LOWER(links.url) LIKE ?",
        search_term, search_term, search_term
      )
    end

    @pagy, @links = pagy(scope, limit: 12)
  end

  def about
    redirect_to dashboard_path if self_hosted?
  end

  def self_host
    redirect_to root_path if self_hosted?
  end

  def privacy
    redirect_to root_path if self_hosted?
  end

  def pricing
    redirect_to root_path if self_hosted?
  end

  private

  def setup_navbar
    case params[:action]
    when "dashboard"
      @page_title = "Dashboard"
      @back_url = root_path
    when "privacy"
      @page_title = "Privacy Policy"
      @back_url = root_path
    when "pricing"
      @page_title = "Pricing"
      @back_url = root_path
    when "self_host"
      @page_title = "Self-Host"
      @back_url = root_path
    end
  end
end
