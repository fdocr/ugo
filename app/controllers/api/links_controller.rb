class Api::LinksController < Api::ApplicationController
  def show
    if admin_api_key?
      @link = Link.includes(:workspace).find_by(slug: params[:id])
    else
      @link = @current_workspace.links.find_by(slug: params[:id])
    end

    if @link.nil?
      render json: { error: "Link not found" }, status: :not_found
    elsif @link.workspace.ugo_access_blocked?
      render json: { error: "This link is unavailable" }, status: :forbidden
    else
      render json: {
        slug: @link.slug,
        url: @link.url,
        domain: @link.workspace.domain
      }
    end
  end
end
