# frozen_string_literal: true

class RobotsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :redirect_to_setup_if_needed
  skip_before_action :relax_csp_for_admin_scripts

  def show
    response.headers["Cache-Control"] = "public, max-age=3600"
    render plain: robots_body, content_type: "text/plain"
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    render plain: "#{robots_comment}\n", content_type: "text/plain"
  end

  private

  def robots_body
    config = AppConfig.shared
    body = "#{robots_comment}\n"

    if config.setup_completed? && config.app_domain.present?
      body << "\nSitemap: https://#{config.app_domain}/sitemap.xml.gz\n"
    end

    body
  end

  def robots_comment
    "# See https://www.robotstxt.org/robotstxt.html for documentation on how to use the robots.txt file"
  end
end
