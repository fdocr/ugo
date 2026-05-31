require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  setup do
    setup_app_config_as_main_app!
    Rails.cache.clear
  end

  test "main app workspace creation assigns a trial end date" do
    user = users(:one)
    workspace = Workspace.create!(name: "Trial New", user: user, plan: :free)

    assert workspace.trial_ends_at.present?
    assert workspace.trial?
    assert_not workspace.ugo_access_blocked?
  end

  test "trial? is false when subscription is active" do
    user = users(:one)
    workspace = Workspace.create!(name: "Subscribed", user: user, plan: :basic)
    workspace.create_subscription!(
      status: :active,
      amount_cents: 900,
      currency: "USD"
    )

    assert workspace.paying?
    assert_not workspace.trial?
    assert_not workspace.ugo_access_blocked?
  end

  test "ugo_access_blocked? is true when trial has ended and there is no subscription" do
    user = users(:one)
    workspace = Workspace.create!(name: "Expired", user: user, plan: :free)
    workspace.update_column(:trial_ends_at, 1.day.ago)
    workspace.recompute_access_blocked!

    assert_not workspace.trial?
    assert workspace.ugo_access_blocked?
    assert workspace.link_limit_reached?
  end

  test "ugo_access_blocked? reads from the denormalized column without touching subscriptions" do
    user = users(:one)
    workspace = Workspace.create!(name: "Cached Block", user: user, plan: :free)
    workspace.update!(trial_ends_at: 1.day.ago)

    assert_predicate workspace.reload, :ugo_access_blocked?
    assert workspace.access_blocked_at.present?, "Callback should backfill the denormalized column"
  end

  test "subscription create flips access back on for blocked workspace" do
    user = users(:one)
    workspace = Workspace.create!(name: "Re-Subscribed", user: user, plan: :basic)
    workspace.update_column(:trial_ends_at, 1.day.ago)
    workspace.recompute_access_blocked!
    assert_predicate workspace, :ugo_access_blocked?

    workspace.create_subscription!(status: :active, amount_cents: 900, currency: "USD")

    assert_not workspace.reload.ugo_access_blocked?
    assert_nil workspace.access_blocked_at
  end

  test "subscription cancel flips access off on next recompute" do
    user = users(:one)
    workspace = Workspace.create!(name: "Cancelled Soon", user: user, plan: :basic)
    sub = workspace.create_subscription!(status: :active, amount_cents: 900, currency: "USD")
    assert_not workspace.reload.ugo_access_blocked?

    workspace.update_column(:trial_ends_at, 1.day.ago)
    sub.update!(status: :cancelled, cancelled_at: Time.current)

    assert_predicate workspace.reload, :ugo_access_blocked?
  end

  test "paying? is true for past_due subscription" do
    user = users(:one)
    workspace = Workspace.create!(name: "Past Due", user: user, plan: :basic)
    workspace.create_subscription!(
      status: :past_due,
      amount_cents: 900,
      currency: "USD"
    )

    assert workspace.paying?
    assert_not workspace.ugo_access_blocked?
  end

  test "event_limit_reached? returns false for trial workspace under basic limit" do
    user = users(:one)
    workspace = Workspace.create!(name: "Trial Under Limit", user: user, plan: :free)
    link = Link.create!(slug: "trial-link-events", workspace: workspace, url: "https://example.com")

    20.times do |i|
      Visit.create!(
        visitable: link,
        ip_address: "192.168.1.#{i % 255}",
        user_agent: "Test Browser",
        timestamp: Time.current.beginning_of_month + i.minutes
      )
    end

    assert workspace.trial?
    assert_not workspace.event_limit_reached?, "Trial workspace should use Basic-tier event limits"
  end

  test "event_limit_reached? returns true when disabled" do
    user = users(:one)
    workspace = Workspace.create!(name: "Disabled Events", user: user, plan: :free)
    workspace.update!(trial_ends_at: 1.day.ago)
    link = Link.create!(slug: "disabled-ev", workspace: workspace, url: "https://example.com")

    Visit.create!(
      visitable: link,
      ip_address: "192.168.1.1",
      user_agent: "Test Browser",
      timestamp: Time.current.beginning_of_month
    )

    assert workspace.event_limit_reached?
  end

  test "event_limit_reached? returns false for basic workspace under limit" do
    user = users(:one)
    workspace = Workspace.create!(name: "Basic Under Limit", user: user, plan: :basic)
    workspace.create_subscription!(
      status: :active,
      amount_cents: 900,
      currency: "USD"
    )

    link = Link.create!(slug: "basic-link-events", workspace: workspace, url: "https://example.com")

    20.times do |i|
      Visit.create!(
        visitable: link,
        ip_address: "192.168.1.#{i % 255}",
        user_agent: "Test Browser",
        timestamp: Time.current.beginning_of_month + i.minutes
      )
    end

    assert_not workspace.event_limit_reached?, "Basic workspace under 10,000 events should not be limited"
  end

  test "event_limit_reached? returns false for dedicated workspace regardless of events" do
    user = users(:one)
    workspace = Workspace.create!(name: "Dedicated No Limit", user: user, plan: :dedicated)
    link = Link.create!(slug: "ded-link-ev", workspace: workspace, url: "https://example.com")

    20.times do |i|
      Visit.create!(
        visitable: link,
        ip_address: "192.168.1.#{i % 255}",
        user_agent: "Test Browser",
        timestamp: Time.current.beginning_of_month + i.minutes
      )
    end

    assert_not workspace.event_limit_reached?, "Dedicated workspace should never be limited"
  end

  test "event_limit_reached? only counts current month events" do
    user = users(:one)
    workspace = Workspace.create!(name: "Current Month Only", user: user, plan: :free)
    link = Link.create!(slug: "scope-ev", workspace: workspace, url: "https://example.com")

    500.times do |i|
      Visit.create!(
        visitable: link,
        ip_address: "192.168.1.#{i % 255}",
        user_agent: "Test Browser",
        timestamp: 1.month.ago.beginning_of_month + i.minutes
      )
    end

    500.times do |i|
      Visit.create!(
        visitable: link,
        ip_address: "192.168.2.#{i % 255}",
        user_agent: "Test Browser",
        timestamp: Time.current.beginning_of_month + i.minutes
      )
    end

    assert_not workspace.event_limit_reached?, "Only current month events should count toward limit"
  end

  test "link_limit_reached? returns false for trial workspace under basic link limit" do
    user = users(:one)
    workspace = Workspace.create!(name: "Trial Links OK", user: user, plan: :free)

    9.times do |i|
      Link.create!(slug: "tlink-#{i}-#{SecureRandom.hex(2)}", workspace: workspace, url: "https://example#{i}.com")
    end

    assert workspace.trial?
    assert_not workspace.link_limit_reached?
  end

  test "link_limit_reached? returns true when disabled" do
    user = users(:one)
    workspace = Workspace.create!(name: "Disabled Links", user: user, plan: :free)
    workspace.update!(trial_ends_at: 1.day.ago)

    assert workspace.link_limit_reached?
  end

  test "link_limit_reached? returns false for basic workspace under limit" do
    user = users(:one)
    workspace = Workspace.create!(name: "Basic Link Under Limit", user: user, plan: :basic)
    workspace.create_subscription!(
      status: :active,
      amount_cents: 900,
      currency: "USD"
    )

    50.times do |i|
      Link.create!(slug: "blink-#{i}-#{SecureRandom.hex(2)}", workspace: workspace, url: "https://example#{i}.com")
    end

    assert_not workspace.link_limit_reached?, "Basic workspace under 1,000 links should not be limited"
  end

  test "link_limit_reached? returns false for dedicated workspace regardless of links" do
    user = users(:one)
    workspace = Workspace.create!(name: "Dedicated Link No Limit", user: user, plan: :dedicated)

    50.times do |i|
      Link.create!(slug: "dlink-#{i}-#{SecureRandom.hex(2)}", workspace: workspace, url: "https://example#{i}.com")
    end

    assert_not workspace.link_limit_reached?, "Dedicated workspace should never be limited"
  end

  test "current_month_events scope works correctly" do
    user = users(:one)
    workspace = Workspace.create!(name: "Scope Test", user: user, plan: :free)
    link = Link.create!(slug: "scope-cm-#{SecureRandom.hex(2)}", workspace: workspace, url: "https://example.com")

    5.times do |i|
      Visit.create!(
        visitable: link,
        ip_address: "192.168.1.#{i}",
        user_agent: "Test Browser",
        timestamp: Time.current.beginning_of_month + i.days
      )
    end

    3.times do |i|
      Visit.create!(
        visitable: link,
        ip_address: "192.168.2.#{i}",
        user_agent: "Test Browser",
        timestamp: 1.month.ago.beginning_of_month + i.days
      )
    end

    current_month_count = workspace.current_month_events.count
    assert_equal 5, current_month_count, "Should only count current month events"
  end

  test "growth plan limits and detection" do
    user = users(:one)
    workspace = Workspace.create!(name: "Growth Test", user: user, plan: "growth")
    workspace.create_subscription!(
      status: :active,
      amount_cents: 1_900,
      currency: "USD"
    )

    assert workspace.growth?
    assert_not workspace.free?
    assert_not workspace.basic?
    assert_not workspace.dedicated?
    assert_not workspace.ugo_access_blocked?
  end

  test "workspace created on self-hosted gets dedicated plan and no trial" do
    setup_app_config_as_self_hosted!

    user = users(:one)
    workspace = Workspace.create!(name: "Self Hosted WS", user: user, plan: "free")

    assert workspace.dedicated?, "Self-hosted workspace should be forced to dedicated plan"
    assert_nil workspace.trial_ends_at
    assert_not workspace.trial?
  end

  test "workspace created on main app keeps free plan enum during trial" do
    setup_app_config_as_main_app!

    user = users(:one)
    workspace = Workspace.create!(name: "Main App WS", user: user, plan: "free")

    assert workspace.free?, "Main app workspace stays on free enum until checkout upgrades plan"
    assert workspace.trial?
  end
end
