# frozen_string_literal: true

class AppConfig
  # Deep linking configuration for the site: which native apps to verify,
  # the optional destination allowlist, and the default bounce target. Kept in
  # its own concern so AppConfig itself stays focused on core site settings.
  module DeepLinkSettings
    extend ActiveSupport::Concern

    # Apple App ID: 10-char Team ID, a dot, then the bundle identifier.
    IOS_APP_ID_FORMAT = /\A[A-Z0-9]{10}\.[a-zA-Z0-9.-]+\z/

    # Universal Links match on path only — query strings (the ?r= target) are
    # never part of AASA matching — so "/r" alone covers every /r?r=... bounce.
    APPLE_BOUNCE_PATHS = [ "/r" ].freeze

    included do
      validates_with HttpUrlValidator, attributes: [ :deep_link_default_destination ], allow_blank: true, if: :deep_link_enabled?
      validate :validate_deep_link_settings
    end

    def deep_link_ios_app_ids_list
      deep_link_ios_app_ids.to_s.split(/[\s,]+/).map(&:strip).reject(&:blank?)
    end

    def deep_link_allowed_domains_list
      deep_link_allowed_domains.to_s.split(/[\s,]+/).map(&:strip).reject(&:blank?)
    end

    def deep_link_android_asset_links_json
      raw = deep_link_android_asset_links.to_s.strip
      return nil if raw.blank?

      parsed = JSON.parse(raw)
      parsed.is_a?(Array) ? parsed : nil
    rescue JSON::ParserError
      nil
    end

    # Apple App Site Association document for this site's deep-link config, or
    # nil when no iOS apps are configured. Served verbatim at
    # /.well-known/apple-app-site-association.
    def apple_app_site_association
      app_ids = deep_link_ios_app_ids_list
      return nil if app_ids.empty?

      {
        applinks: {
          apps: [],
          details: app_ids.map do |app_id|
            {
              appID: app_id,
              paths: APPLE_BOUNCE_PATHS,
              components: APPLE_BOUNCE_PATHS.map { |path| { "/": path } }
            }
          end
        },
        activitycontinuation: {
          apps: app_ids
        }
      }
    end

    private

    def validate_deep_link_settings
      return unless deep_link_enabled?

      deep_link_ios_app_ids_list.each do |app_id|
        unless app_id.match?(IOS_APP_ID_FORMAT)
          errors.add(:deep_link_ios_app_ids, "contains an invalid app ID: #{app_id}")
        end
      end

      if deep_link_android_asset_links.to_s.strip.present? && deep_link_android_asset_links_json.nil?
        errors.add(:deep_link_android_asset_links, "must be valid JSON array")
      end
    end
  end
end
