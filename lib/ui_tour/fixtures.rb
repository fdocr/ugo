module UiTour
  # Deterministic seed for the tour database. Builds a small but representative
  # set of users, workspaces in different billing states, links with visits,
  # and pending invitations so screenshots tell a coherent story.
  #
  # Run before every tour by UiTour::Runner so each invocation captures a
  # known, reproducible UI state.
  class Fixtures
    PASSWORD = "password123".freeze

    ADMIN_EMAIL = "admin@example.com".freeze
    OWNER_EMAIL = "owner@example.com".freeze
    MEMBER_EMAIL = "member@example.com".freeze
    INVITEE_EMAIL = "invitee@example.com".freeze

    def self.seed!(mode:)
      new(mode: mode).seed!
    end

    def initialize(mode:)
      @mode = mode
    end

    def seed!
      configure_app!
      build_users!
      build_workspaces!
      build_links_and_visits!
      build_invitations!

      AppConfig.send(:reset_caches!)
      true
    end

    private

    def configure_app!
      cfg = AppConfig.shared
      attrs =
        if @mode == :self_hosted
          { setup_completed: true, app_name: "Acme Links", app_domain: "links.acme.test" }
        else
          { setup_completed: true, app_name: "ugo", app_domain: AppConfig::UGO_DOMAIN }
        end
      cfg.update!(attrs)
      AppConfig.send(:reset_caches!)
    end

    def build_users!
      @admin = upsert_user(ADMIN_EMAIL, site_admin: true)
      @owner = upsert_user(OWNER_EMAIL)
      @member = upsert_user(MEMBER_EMAIL)
    end

    def upsert_user(email, site_admin: false)
      user = User.find_or_initialize_by(email: email)
      user.password = PASSWORD
      user.password_confirmation = PASSWORD
      user.site_admin = site_admin
      user.save!
      user
    end

    def build_workspaces!
      @workspaces = {}

      @workspaces[:trial] = ensure_workspace(@admin, "Acme Marketing", trial_days_remaining: 9)
      @workspaces[:basic] = ensure_workspace(@admin, "Acme Sales") do |w|
        attach_subscription!(w, status: :active, amount_cents: 900, plan: :basic)
      end
      @workspaces[:past_due] = ensure_workspace(@owner, "Beta Co", trial_days_remaining: nil) do |w|
        attach_subscription!(w, status: :past_due, amount_cents: 900, plan: :basic)
      end
      @workspaces[:expired_trial] = ensure_workspace(@owner, "Old Trial", trial_days_remaining: -3)
      @workspaces[:cancelled] = ensure_workspace(@owner, "Quit Club") do |w|
        attach_subscription!(w, status: :cancelled, amount_cents: 900, plan: :basic, cancelled_at: 2.days.ago)
      end

      Membership.find_or_create_by!(workspace: @workspaces[:trial], user: @member) do |m|
        m.role = :member
      end
    end

    def ensure_workspace(user, name, trial_days_remaining: nil)
      workspace = Workspace.find_or_initialize_by(name: name)
      is_new = workspace.new_record?
      workspace.user ||= user

      if AppConfig.self_hosted?
        workspace.plan = :dedicated
      else
        workspace.plan ||= :free
        if trial_days_remaining
          workspace.trial_ends_at = trial_days_remaining.days.from_now
        elsif workspace.trial_ends_at.blank?
          workspace.trial_ends_at = nil
        end
      end

      workspace.save!
      Membership.find_or_create_by!(workspace: workspace, user: user) { |m| m.role = :admin } if is_new
      yield(workspace) if block_given?
      workspace.recompute_access_blocked!
      workspace
    end

    def attach_subscription!(workspace, status:, amount_cents:, plan:, cancelled_at: nil)
      sub = workspace.subscription || workspace.build_subscription
      sub.assign_attributes(
        status: status,
        amount_cents: amount_cents,
        currency: "USD",
        polar_subscription_id: "fake_#{workspace.id}_#{status}",
        current_period_end: 27.days.from_now,
        cancelled_at: cancelled_at
      )
      sub.save!
      workspace.update!(plan: plan) unless workspace.plan == plan.to_s || AppConfig.self_hosted?
      sub
    end

    def build_links_and_visits!
      seed_workspace_links(@workspaces[:trial], [
        { name: "Spring Campaign", slug: "spring-2026", url: "https://acme.example.com/spring", count: 220 },
        { name: "Newsletter Signup", slug: "newsletter", url: "https://acme.example.com/newsletter", count: 80 },
        { name: "Product Demo", slug: "demo", url: "https://acme.example.com/demo", count: 140 }
      ])
      seed_workspace_links(@workspaces[:basic], [
        { name: "Sales Deck", slug: "deck", url: "https://acme.example.com/deck", count: 60 }
      ])
    end

    def seed_workspace_links(workspace, link_specs)
      link_specs.each do |spec|
        link = Link.find_or_initialize_by(workspace: workspace, slug: spec[:slug])
        link.name = spec[:name]
        link.url = spec[:url]
        link.comments = "Tour fixture link"
        link.save!
        seed_visits(link, spec[:count]) if Visit.where(visitable_type: "Link", visitable_id: link.id).count.zero?
      end
    end

    def seed_visits(link, count)
      countries = [
        { country: "United States", code: "US", city: "New York", sub: "New York" },
        { country: "United Kingdom", code: "GB", city: "London", sub: "England" },
        { country: "Germany", code: "DE", city: "Berlin", sub: "Berlin" },
        { country: "Canada", code: "CA", city: "Toronto", sub: "Ontario" },
        { country: "Costa Rica", code: "CR", city: "San José", sub: "San José" }
      ]
      devices = %w[desktop mobile mobile desktop tablet]
      browsers = %w[Chrome Safari Firefox Edge]
      os_list = %w[macOS Windows iOS Android Linux]
      referers = [ "https://google.com", "https://twitter.com", nil, "https://reddit.com" ]
      now = Time.current

      rows = count.times.map do |i|
        c = countries[i % countries.size]
        ts = now - (rand(0..29).days + rand(0..23).hours + rand(0..59).minutes)
        {
          visitable_type: "Link",
          visitable_id: link.id,
          ip_address: "203.0.113.#{(i % 250) + 1}",
          user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
          timestamp: ts,
          processed_at: ts + rand(1..15).seconds,
          country: c[:country],
          country_code: c[:code],
          city: c[:city],
          subdivision: c[:sub],
          device_type: devices[i % devices.size],
          browser_name: browsers[i % browsers.size],
          os_name: os_list[i % os_list.size],
          referer: referers[i % referers.size],
          # Roughly 3 visits per unique visitor for a realistic-looking ratio.
          visitor_hash: "tourfix#{(i / 3).to_s.rjust(8, "0").ljust(24, "0")}",
          latitude: 0.0,
          longitude: 0.0,
          accuracy_radius: 50
        }
      end
      Visit.insert_all(rows) if rows.any?
    end

    def build_invitations!
      ws = @workspaces[:basic]
      return if ws.invitations.pending.where(email: INVITEE_EMAIL).exists?
      ws.invitations.create!(email: INVITEE_EMAIL, role: :member, invited_by: @admin)
    end
  end
end
