class LinksController < ApplicationController
  include EnforceUgoWorkspaceAccess

  allow_unauthenticated_access only: [ :link ]
  skip_before_action :redirect_to_setup_if_needed, only: [ :link ]
  skip_before_action :relax_csp_for_admin_scripts, only: [ :link ]

  rate_limit to: 30, within: 1.minute, only: :link,
    by: -> { "#{request.remote_ip}|#{request.path}" },
    with: -> { render "links/link_rate_limited", layout: false, status: :too_many_requests }

  before_action :load_workspace, except: [ :link, :new ]
  before_action :authorize_workspace_member!, except: [ :link, :new ]
  before_action :ensure_ugo_workspace_active!, except: [ :link, :new ]
  before_action :ensure_usable_workspace_for_new_link!, only: [ :new ]
  before_action :load_link, only: [ :show, :destroy, :edit, :update, :social_tag ]
  before_action :setup_navbar, except: [ :link ]

  after_action :track_visit, only: [ :link ]

  # Public redirect endpoint. The hot path here must stay query-cheap:
  # we issue exactly two SELECTs against the primary DB (links joined with
  # workspaces for the denormalized access flag, plus social_tag for the OG
  # meta cache fragment) and defer the visit INSERT to a Solid Queue job
  # backed by its own SQLite file so the primary writer lock stays free.
  def link
    @link = Link
      .joins("INNER JOIN workspaces ON workspaces.id = links.workspace_id")
      .where(banned_at: nil)
      .select(
        "links.id, links.name, links.url, links.updated_at, links.banned_at," \
        " links.workspace_id," \
        " workspaces.access_blocked_at AS workspace_access_blocked_at"
      )
      .includes(:social_tag)
      .find_by(slug: params[:id])

    if @link&.url.nil?
      redirect_to root_path, notice: "Link not found"
    elsif workspace_access_blocked_for?(@link)
      response.headers["Cache-Control"] = "private, no-store"
      render "links/link_unavailable", layout: false, status: :payment_required
    else
      response.headers["Cache-Control"] = "private, no-store"
      render layout: false
    end
  end

  def show
  end

  def new
    @workspaces = Current.user.workspaces
    @link = Link.new
  end

  def create
    if @workspace.link_limit_reached?
      alert =
        if @workspace.trial? || @workspace.basic?
          "You have reached the link limit for #{@workspace.name}. Upgrade to Growth for more capacity."
        else
          "You have reached the link limit for #{@workspace.name}. Consider upgrading your plan."
        end
      redirect_to dashboard_path, alert: alert
      return
    end

    @link = Link.new(link_params.merge(workspace: @workspace))
    @link.save_with_new_slug

    if @link.persisted?
      redirect_to workspace_link_path(@workspace.id, @link.slug), notice: "Link was successfully created."
    else
      Rails.logger.error "Error: #{@link.errors_as_sentence}"
      redirect_to new_link_path, alert: "Error: #{@link.errors_as_sentence}"
    end
  end

  def update
    if @link.update(link_params)
      redirect_to workspace_link_path(@workspace.id, @link.slug), notice: "Link was successfully updated"
    else
      redirect_to workspace_link_path(@workspace.id, @link.slug), alert: "Failed to update link: #{@link.errors_as_sentence}"
    end
  end

  def destroy
    if @link.destroy
      redirect_to dashboard_path, notice: "Link was successfully deleted"
    else
      redirect_to workspace_link_path(@workspace.id, @link.slug), alert: "Failed to delete link: #{@link.errors_as_sentence}"
    end
  end

  def social_tag
    social_tag = @link.social_tag

    unless social_tag
      flash.now[:alert] = "Social preview is not available yet."
      return respond_to_social_tag
    end

    social_tag.with_lock do
      social_tag.reload
      if social_tag.updated_at >= SocialTag::REFRESH_COOLDOWN.ago
        flash.now[:alert] = "You can only refresh social tags once every 5 minutes. Try again soon."
      else
        social_tag.touch
        SyncSocialTagJob.perform_later(slug: @link.slug)
        flash.now[:notice] = "Social tag is being fetched and updated. This can take a few minutes to update the preview"
      end
    end

    respond_to_social_tag
  end

  private

  def respond_to_social_tag
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream_flash }
      format.html do
        redirect_options = { notice: flash.now[:notice], alert: flash.now[:alert] }.compact
        redirect_to workspace_link_path(@workspace.id, @link.slug), **redirect_options
      end
    end
  end

  def turbo_stream_flash
    turbo_stream.update("flash", partial: "shared/flash")
  end

  def workspace_access_blocked_for?(link)
    return false if AppConfig.self_hosted?
    link.workspace_access_blocked_at.present?
  end

  def track_visit
    return if response.status == 429
    return unless @link&.url.present?
    return if workspace_access_blocked_for?(@link)
    return if CrawlerDetect.new(request.user_agent).is_crawler?

    RecordVisitJob.perform_later(
      visitable: @link,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      referer: request.referer,
      timestamp: Time.current
    )
  end

  def load_link
    @link = @workspace.links.find_by(slug: params[:id])
    redirect_to dashboard_path, notice: "Link not found" if @link.nil?
  end

  def load_workspace
    @workspace = Current.user.workspaces.find_by(id: params[:workspace_id])
    redirect_to dashboard_path, notice: "Workspace not found" if @workspace.nil?
  end

  def link_params
    params.permit(:name, :url, :comments)
  end

  def ensure_usable_workspace_for_new_link!
    return if AppConfig.self_hosted?
    return if Current.user.workspaces.where(access_blocked_at: nil).exists?

    redirect_to dashboard_path, alert: "Your workspaces need an active subscription before you can create links."
  end

  def setup_navbar
    case params[:action]
    when "new"
      @page_title = "New link"
      @back_url = dashboard_path
    when "edit"
      @page_title = "Edit link"
      @back_url = workspace_link_path(@workspace.id, @link.slug)
    when "show"
      @page_title = @link.slug
      @back_url = dashboard_path
    end
  end
end
