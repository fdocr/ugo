# frozen_string_literal: true

class WellKnownController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :redirect_to_setup_if_needed
  skip_before_action :relax_csp_for_admin_scripts

  def apple_app_site_association
    render_well_known { AppConfig.shared.apple_app_site_association }
  end

  def asset_links
    render_well_known { AppConfig.shared.deep_link_android_asset_links_json }
  end

  private

  # Both well-known endpoints share the same shape: serve the payload with a
  # one-hour cache when deep linking is on, otherwise 404. The DB rescue covers
  # requests that land before setup/migration.
  def render_well_known
    payload = yield

    if AppConfig.shared.deep_link_enabled? && payload.present?
      response.headers["Cache-Control"] = "public, max-age=3600"
      render json: payload
    else
      head :not_found
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    head :not_found
  end
end
