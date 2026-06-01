require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @site_admin = users(:one)
    @regular_user = users(:two)
    @workspace = workspaces(:one)
  end

  # Authentication tests
  test "should redirect to login when not authenticated for index" do
    get admin_root_path
    assert_redirected_to new_session_path
  end

  test "should redirect to login when not authenticated for workspaces" do
    get admin_workspaces_path
    assert_redirected_to new_session_path
  end

  test "should redirect to login when not authenticated for links" do
    get admin_links_path
    assert_redirected_to new_session_path
  end

  # Authorization tests - Site admin
  test "site admin can access index" do
    sign_in @site_admin

    get admin_root_path
    assert_response :success
    assert_select "h3", "Overview"
  end

  test "site admin can access workspaces" do
    sign_in @site_admin

    get admin_workspaces_path
    assert_response :success
    assert_select "table"
  end

  test "site admin can access links" do
    sign_in @site_admin

    get admin_links_path
    assert_response :success
    assert_select "table"
  end

  # Authorization tests - Regular user
  test "regular user cannot access index" do
    sign_in @regular_user

    get admin_root_path
    assert_redirected_to "/"
    assert_equal "You are not authorized to access this page", flash[:alert]
  end

  test "regular user cannot access workspaces" do
    sign_in @regular_user

    get admin_workspaces_path
    assert_redirected_to "/"
    assert_equal "You are not authorized to access this page", flash[:alert]
  end

  test "regular user cannot access links" do
    sign_in @regular_user

    get admin_links_path
    assert_redirected_to "/"
    assert_equal "You are not authorized to access this page", flash[:alert]
  end

  # Functionality tests
  test "index shows stats" do
    sign_in @site_admin

    get admin_root_path
    assert_response :success

    # Verify stats cards are present
    assert_select "div.text-2xl", minimum: 4
    assert_select ".text-muted-foreground", text: "Deep link destinations"
  end

  test "index tolerates stale cached stats missing deep link keys" do
    sign_in @site_admin
    Rails.cache.write(
      Admin::DashboardStats::CACHE_KEY,
      {
        users: { total: 1 },
        workspaces: { free: 0, basic: 0, dedicated: 0, total: 0 },
        links: { total: 0 },
        visits: { last_7_days: 0 }
      },
      expires_in: 1.hour
    )

    get admin_root_path
    assert_response :success
  end

  test "workspaces page is paginated" do
    sign_in @site_admin

    get admin_workspaces_path
    assert_response :success
    assert_select "table tbody tr", minimum: 1
  end

  test "links page is paginated" do
    sign_in @site_admin

    get admin_links_path
    assert_response :success
    assert_select "table tbody tr", minimum: 1
  end

  test "links page can sort by recent" do
    sign_in @site_admin

    get admin_links_path(sort: "recent")
    assert_response :success
  end

  test "links page can sort by visits" do
    sign_in @site_admin

    get admin_links_path(sort: "visits")
    assert_response :success
  end

  test "deep_links page is reachable and paginated" do
    sign_in @site_admin
    DeepLink.create!(destination_url: "https://example.com/app", destination_host: "example.com")

    get admin_deep_links_path
    assert_response :success
    assert_select "table"
  end

  test "deep_links page can sort by recent and by visits" do
    sign_in @site_admin
    DeepLink.create!(destination_url: "https://example.com/app", destination_host: "example.com")

    get admin_deep_links_path(sort: "recent")
    assert_response :success

    get admin_deep_links_path(sort: "visits")
    assert_response :success
  end

  test "deep_links page can be searched by host" do
    sign_in @site_admin
    DeepLink.create!(destination_url: "https://findme.example.com/app", destination_host: "findme.example.com")

    get admin_deep_links_path(search: "findme")
    assert_response :success
    assert_select "table tbody tr", minimum: 1
  end

  test "deep_links renders the 7-day bounce count from the grouped query" do
    sign_in @site_admin
    deep_link = DeepLink.create!(destination_url: "https://counted.example.com/app", destination_host: "counted.example.com")
    2.times { |i| visit_for(deep_link, timestamp: 1.day.ago, hash: "recent#{i}") }
    visit_for(deep_link, timestamp: 30.days.ago, hash: "old")

    get admin_deep_links_path(search: "counted")
    assert_response :success
    assert_select "td span.font-medium", text: "2"
  end

  # Turbo frame tests
  test "deep_links responds to turbo frame request" do
    sign_in @site_admin

    get admin_deep_links_path, headers: { "Turbo-Frame" => "admin-deep-links" }
    assert_response :success
    assert_select "turbo-frame#admin-deep-links"
  end

  test "workspaces responds to turbo frame request" do
    sign_in @site_admin

    get admin_workspaces_path, headers: { "Turbo-Frame" => "admin-workspaces" }
    assert_response :success
    assert_select "turbo-frame#admin-workspaces"
  end

  test "links responds to turbo frame request" do
    sign_in @site_admin

    get admin_links_path, headers: { "Turbo-Frame" => "admin-links" }
    assert_response :success
    assert_select "turbo-frame#admin-links"
  end

  # Search tests
  test "workspaces can be searched by owner email" do
    sign_in @site_admin

    get admin_workspaces_path(search: @workspace.user.email)
    assert_response :success
    assert_select "table tbody tr", minimum: 1
    assert_select "span.font-medium", text: @workspace.name
  end

  test "workspaces search is case insensitive" do
    sign_in @site_admin

    get admin_workspaces_path(search: @workspace.user.email.upcase)
    assert_response :success
    assert_select "table tbody tr", minimum: 1
  end

  test "workspaces search shows no results message when no matches" do
    sign_in @site_admin

    get admin_workspaces_path(search: "nonexistent@email.com")
    assert_response :success
    assert_select "td", text: /No workspaces found matching/
  end

  test "workspaces page can sort by recent" do
    sign_in @site_admin

    get admin_workspaces_path(sort: "recent")
    assert_response :success
  end

  test "workspaces page can sort by links" do
    sign_in @site_admin

    get admin_workspaces_path(sort: "links")
    assert_response :success
  end

  test "workspaces search preserves sort parameter" do
    sign_in @site_admin

    get admin_workspaces_path(search: "test", sort: "links")
    assert_response :success
    assert_select "a[href*='sort=links']"
  end

  test "links can be searched by url" do
    sign_in @site_admin
    link = links(:one)
    link.update!(url: "https://example.com/test")

    get admin_links_path(search: "example.com")
    assert_response :success
    assert_select "table tbody tr", minimum: 1
  end

  test "links search is case insensitive" do
    sign_in @site_admin
    link = links(:one)
    link.update!(url: "https://Example.COM/test")

    get admin_links_path(search: "example.com")
    assert_response :success
    assert_select "table tbody tr", minimum: 1
  end

  test "links search preserves sort parameter" do
    sign_in @site_admin

    get admin_links_path(search: "test", sort: "visits")
    assert_response :success
    # Verify the sort toggle still shows visits as active
    assert_select "a[href*='sort=visits']"
  end

  test "links search shows no results message when no matches" do
    sign_in @site_admin

    get admin_links_path(search: "nonexistent-url-12345")
    assert_response :success
    assert_select "td", text: /No links found matching/
  end

  # Ban/Unban tests
  test "should redirect to login when not authenticated for ban_user" do
    user_to_ban = User.create!(email: "toban@example.com", password: "password123")

    post admin_ban_user_path(user_to_ban)
    assert_redirected_to new_session_path
  end

  test "should redirect to login when not authenticated for unban_user" do
    user_to_unban = User.create!(email: "tounban@example.com", password: "password123", banned_at: Time.current)

    post admin_unban_user_path(user_to_unban)
    assert_redirected_to new_session_path
  end

  test "regular user cannot access ban_user" do
    sign_in @regular_user
    user_to_ban = User.create!(email: "toban@example.com", password: "password123")

    post admin_ban_user_path(user_to_ban)
    assert_redirected_to "/"
    assert_equal "You are not authorized to access this page", flash[:alert]
  end

  test "regular user cannot access unban_user" do
    sign_in @regular_user
    user_to_unban = User.create!(email: "tounban@example.com", password: "password123", banned_at: Time.current)

    post admin_unban_user_path(user_to_unban)
    assert_redirected_to "/"
    assert_equal "You are not authorized to access this page", flash[:alert]
  end

  test "site admin can ban user" do
    sign_in @site_admin
    user_to_ban = User.create!(email: "toban@example.com", password: "password123")
    assert_not user_to_ban.banned?

    post admin_ban_user_path(user_to_ban)

    assert_redirected_to admin_root_path
    assert_match "has been banned", flash[:notice]
    user_to_ban.reload
    assert user_to_ban.banned?
  end

  test "site admin can unban user" do
    sign_in @site_admin
    user_to_unban = User.create!(email: "tounban@example.com", password: "password123", banned_at: Time.current)
    assert user_to_unban.banned?

    post admin_unban_user_path(user_to_unban)

    assert_redirected_to admin_root_path
    assert_match "has been unbanned", flash[:notice]
    user_to_unban.reload
    assert_not user_to_unban.banned?
  end

  test "banning user destroys their sessions" do
    sign_in @site_admin
    user_to_ban = User.create!(email: "toban@example.com", password: "password123")
    Session.create!(user: user_to_ban, ip_address: "127.0.0.1", user_agent: "Test")
    assert_equal 1, user_to_ban.sessions.count

    post admin_ban_user_path(user_to_ban)

    user_to_ban.reload
    assert_equal 0, user_to_ban.sessions.count
  end

  test "banning user enqueues job to ban links" do
    sign_in @site_admin
    user_to_ban = User.create!(email: "toban@example.com", password: "password123")

    assert_enqueued_with(job: BanUserLinksJob, args: [ { user_id: user_to_ban.id, ban: true } ]) do
      post admin_ban_user_path(user_to_ban)
    end
  end

  test "unbanning user enqueues job to unban links" do
    sign_in @site_admin
    user_to_unban = User.create!(email: "tounban@example.com", password: "password123", banned_at: Time.current)

    assert_enqueued_with(job: BanUserLinksJob, args: [ { user_id: user_to_unban.id, ban: false } ]) do
      post admin_unban_user_path(user_to_unban)
    end
  end

  # -- Settings page tests --

  test "should redirect to login when not authenticated for settings" do
    get admin_settings_path
    assert_redirected_to new_session_path
  end

  test "regular user cannot access settings" do
    sign_in @regular_user

    get admin_settings_path
    assert_redirected_to "/"
    assert_equal "You are not authorized to access this page", flash[:alert]
  end

  test "site admin can access settings" do
    sign_in @site_admin

    get admin_settings_path
    assert_response :success
    assert_select "h2", text: "Site Settings"
  end

  test "site admin can update settings" do
    sign_in @site_admin

    patch admin_settings_path, params: {
      app_name: "Updated App",
      app_domain: "new.example.com",
      smtp_address: "smtp.new.com",
      smtp_port: "465",
      smtp_username: "user@new.com",
      smtp_from_email: "noreply@new.com"
    }

    assert_redirected_to admin_settings_path
    assert_match "Settings updated", flash[:notice]

    config = AppConfig.shared.reload
    assert_equal "Updated App", config.app_name
    assert_equal "new.example.com", config.app_domain
    assert_equal "smtp.new.com", config.smtp_address
    assert_equal 465, config.smtp_port
  end

  test "site admin can update admin_scripts" do
    sign_in @site_admin

    snippet = "<script>/* analytics */</script>"
    patch admin_settings_path, params: {
      app_name: "ugo",
      app_domain: "ugo.cr",
      smtp_address: "",
      smtp_port: "587",
      smtp_username: "",
      smtp_from_email: "noreply@example.com",
      admin_scripts: snippet
    }

    assert_redirected_to admin_settings_path
    assert_equal snippet, AppConfig.shared.reload.admin_scripts
  end

  test "main app settings page includes Polar configuration" do
    setup_app_config_as_main_app!
    sign_in @site_admin

    get admin_settings_path
    assert_response :success
    assert_select "h3", text: "Payments (Polar)"
  end

  test "self-hosted settings page does not include Polar configuration" do
    setup_app_config_as_self_hosted!
    sign_in @site_admin

    get admin_settings_path
    assert_response :success
    assert_select "h3", { text: "Payments (Polar)", count: 0 }
  end

  test "self-hosted update ignores polar params" do
    setup_app_config_as_self_hosted!
    AppConfig.shared.update!(
      polar_basic_product_id: "keep-basic",
      polar_growth_product_id: "keep-growth",
      polar_sandbox: false
    )

    sign_in @site_admin

    patch admin_settings_path, params: {
      app_name: "ugo",
      app_domain: "links.mycompany.com",
      smtp_address: "",
      smtp_port: "587",
      smtp_username: "",
      smtp_from_email: "noreply@example.com",
      polar_basic_product_id: "injected",
      polar_growth_product_id: "injected",
      polar_sandbox: "1",
      polar_access_token: "evil-token"
    }

    assert_redirected_to admin_settings_path

    config = AppConfig.shared.reload
    assert_equal "keep-basic", config.polar_basic_product_id
    assert_equal "keep-growth", config.polar_growth_product_id
    assert_not config.polar_sandbox
    assert_not_equal "evil-token", config.polar_access_token
  end

  test "site admin can clear polar product ids on main app" do
    sign_in @site_admin
    setup_app_config_as_main_app!
    AppConfig.shared.update!(polar_basic_product_id: "bid", polar_growth_product_id: "gid")

    patch admin_settings_path, params: {
      app_name: "ugo",
      app_domain: "ugo.cr",
      smtp_address: "",
      smtp_port: "587",
      smtp_username: "",
      smtp_from_email: "noreply@example.com",
      polar_basic_product_id: "",
      polar_growth_product_id: "",
      polar_sandbox: "0"
    }

    assert_redirected_to admin_settings_path
    config = AppConfig.shared.reload
    assert_equal "", config.polar_basic_product_id
    assert_equal "", config.polar_growth_product_id
  end

  test "site admin can update settings without changing SMTP password" do
    sign_in @site_admin

    # Set an initial SMTP password
    AppConfig.shared.update!(smtp_password: "original-secret")

    patch admin_settings_path, params: {
      app_name: "Updated App",
      app_domain: "ugo.cr",
      smtp_address: "",
      smtp_port: "587",
      smtp_username: "",
      smtp_password: "",
      smtp_from_email: ""
    }

    assert_redirected_to admin_settings_path

    config = AppConfig.shared.reload
    assert_equal "original-secret", config.smtp_password
  end

  test "regular user cannot update settings" do
    sign_in @regular_user

    patch admin_settings_path, params: { app_name: "Hacked" }
    assert_redirected_to "/"
  end

  # -- Self-hosted user creation tests --

  test "new_user redirects to workspace invite flow on self-hosted" do
    setup_app_config_as_self_hosted!
    sign_in @site_admin

    get admin_new_user_path
    assert_redirected_to workspace_path(@site_admin.workspaces.first)
  end

  test "create_user redirects on main app" do
    sign_in @site_admin

    get admin_new_user_path
    assert_redirected_to admin_root_path
    assert_match "only available on self-hosted", flash[:alert]
  end

  test "site admin can create user on self-hosted" do
    setup_app_config_as_self_hosted!
    sign_in @site_admin

    assert_difference "User.count", 1 do
      post admin_create_user_path, params: { email: "newuser@company.com" }
    end

    assert_redirected_to admin_root_path
    assert_match "newuser@company.com", flash[:notice]
  end

  test "create_user adds to admin workspace on self-hosted" do
    setup_app_config_as_self_hosted!
    sign_in @site_admin

    assert_no_difference "Workspace.count" do
      assert_difference "Membership.count", 1 do
        post admin_create_user_path, params: { email: "team@company.com" }
      end
    end

    user = User.find_by(email: "team@company.com")
    admin_workspace = @site_admin.workspaces.first
    assert admin_workspace.member?(user), "New user should be a member of the admin's workspace"
  end


  test "create_user POST blocked on main app" do
    sign_in @site_admin

    assert_no_difference "User.count" do
      post admin_create_user_path, params: { email: "newuser@company.com" }
    end

    assert_redirected_to admin_root_path
    assert_match "only available on self-hosted", flash[:alert]
  end

  private

  def sign_in(user)
    post session_path, params: { email: user.email, password: "password123" }
  end

  def visit_for(visitable, timestamp:, hash:)
    Visit.create!(
      visitable: visitable,
      ip_address: nil,
      timestamp: timestamp,
      processed_at: timestamp,
      visitor_hash: hash
    )
  end
end
