# frozen_string_literal: true

require "test_helper"

module Admin
  class DashboardStatsTest < ActiveSupport::TestCase
    setup do
      Rails.cache.delete(DashboardStats::CACHE_KEY)
    end

    test "fetch returns all expected keys" do
      stats = DashboardStats.fetch
      assert stats.dig(:users, :total).is_a?(Integer)
      assert stats.dig(:deep_links, :total).is_a?(Integer)
      assert stats.dig(:deep_link_visits, :last_7_days).is_a?(Integer)
    end

    test "dig returns default for missing keys in stale cache payloads" do
      Rails.cache.write(
        DashboardStats::CACHE_KEY,
        { users: { total: 3 }, workspaces: { free: 0, basic: 0, dedicated: 0, total: 0 },
          links: { total: 1 }, visits: { last_7_days: 10 } },
        expires_in: 1.hour
      )

      stats = DashboardStats.fetch
      assert_equal 0, stats.dig(:deep_links, :total)
      assert_equal 0, stats.dig(:deep_link_visits, :last_7_days)
    end
  end
end
