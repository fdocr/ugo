# frozen_string_literal: true

module Admin
  # Site-wide counts for the admin dashboard. Cached to avoid N+1 count queries
  # on every /admin visit. Bump CACHE_VERSION when the stats shape changes so
  # stale entries are not served (see deep-link-bounce rollout).
  class DashboardStats
    CACHE_VERSION = 2
    CACHE_KEY = "admin/dashboard_stats/v#{CACHE_VERSION}"
    CACHE_TTL = 10.minutes

    def self.fetch
      new(Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) { build_hash })
    end

    def self.build_hash
      {
        workspaces: {
          free: Workspace.free.count,
          basic: Workspace.basic.count,
          dedicated: Workspace.dedicated.count,
          total: Workspace.count
        },
        links: {
          total: Link.count
        },
        users: {
          total: User.count
        },
        visits: {
          last_7_days: Visit.recent.count
        },
        deep_link_visits: {
          last_7_days: Visit.for_deep_links.recent.count
        },
        deep_links: {
          total: DeepLink.count
        }
      }
    end

    def initialize(data)
      @data = data.deep_symbolize_keys
    end

    def dig(*keys, default: 0)
      @data.dig(*keys) || default
    end
  end
end
