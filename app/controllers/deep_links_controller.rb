# frozen_string_literal: true

class DeepLinksController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :redirect_to_setup_if_needed
  skip_before_action :relax_csp_for_admin_scripts

  after_action :track_deep_link_visit, only: :bounce

  rate_limit to: 30, within: 1.minute, only: :bounce,
    by: -> { "#{request.remote_ip}|#{request.path}" },
    with: -> { render "deep_links/rate_limited", layout: false, status: :too_many_requests }

  def bounce
    config = AppConfig.shared
    return head :not_found unless config.deep_link_enabled?

    target = params[:r].presence || config.deep_link_default_destination.presence

    if target.blank?
      @error_message = "Missing redirect parameter. Use /r?r= followed by an https:// destination URL."
      return render "deep_links/error", layout: false, status: :bad_request
    end

    destination = DeepLink::Target.new(target)
    @bounce_target = destination.url

    if config.deep_link_allowed_domains_list.any? &&
        !destination.allowed?(domains: config.deep_link_allowed_domains)
      @error_message = "That destination is not allowed for this site."
      return render "deep_links/error", layout: false, status: :forbidden
    end

    response.headers["Cache-Control"] = "private, no-store"
    redirect_to @bounce_target, allow_other_host: true, status: :found
  rescue DeepLink::Target::InvalidTarget => e
    @error_message = e.message
    render "deep_links/error", layout: false, status: :bad_request
  end

  private

  def track_deep_link_visit
    return if response.status == 429
    return if response.status >= 400
    return if @bounce_target.blank?
    return if CrawlerDetect.new(request.user_agent).is_crawler?

    RecordVisitJob.perform_later(
      visitable_url: @bounce_target,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      referer: request.referer,
      timestamp: Time.current
    )
  end
end
