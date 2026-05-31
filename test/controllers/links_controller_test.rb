require "test_helper"

class LinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:one)
    @link = links(:one)
    @owner = users(:one)
    @member = users(:two) # User two is a member of workspace one
  end

  # Public link access (no authentication required)
  test "anyone can access public link redirect" do
    get link_redirect_path(@link.slug), headers: { "User-Agent" => "TestBrowser/1.0" }
    assert_response :success
  end

  test "public link redirects to root for non-existing link" do
    get link_redirect_path("nonexistent"), headers: { "User-Agent" => "TestBrowser/1.0" }
    assert_redirected_to root_path
  end

  test "banned link redirects to root with link not found" do
    @link.update!(banned_at: Time.current)

    get link_redirect_path(@link.slug), headers: { "User-Agent" => "TestBrowser/1.0" }
    assert_redirected_to root_path
    assert_equal "Link not found", flash[:notice]
  end

  test "public link returns payment_required when workspace is disabled after trial" do
    setup_app_config_as_main_app!
    user = users(:one)
    workspace = Workspace.create!(name: "Expired Trial WS", user: user, plan: :free)
    workspace.update_column(:trial_ends_at, 1.day.ago)
    workspace.recompute_access_blocked!
    link = Link.create!(name: "Test", slug: "x#{SecureRandom.hex(4)}", workspace: workspace, url: "https://example.com")

    get link_redirect_path(link.slug), headers: { "User-Agent" => "TestBrowser/1.0" }
    assert_response :payment_required
    assert_includes response.body, "unavailable"
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "successful redirect sets Cache-Control private no-store" do
    get link_redirect_path(@link.slug), headers: { "User-Agent" => "TestBrowser/1.0" }
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
  end

  test "redirect endpoint records visits asynchronously, not synchronously" do
    assert_no_difference "Visit.count" do
      assert_enqueued_with(job: RecordVisitJob) do
        get link_redirect_path(@link.slug), headers: { "User-Agent" => "TestBrowser/1.0" }
      end
    end
    assert_response :success
  end

  test "redirect endpoint stays on a fixed query budget on the hot path" do
    # Hot-path budget: 1 SELECT for link+workspace (single JOIN) + 1 SELECT for
    # social_tag preload. No subscription lookup, no app_configs lookup, no
    # synchronous Visit INSERT against the primary DB.
    Rails.cache.clear
    AppConfig.send(:reset_caches!)
    get link_redirect_path(@link.slug), headers: { "User-Agent" => "TestBrowser/1.0" }
    assert_response :success

    queries = []
    callback = ->(_, _, _, _, payload) {
      next if [ "SCHEMA", "TRANSACTION" ].include?(payload[:name])
      queries << payload[:sql]
    }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get link_redirect_path(@link.slug), headers: { "User-Agent" => "TestBrowser/1.0" }
    end
    assert_response :success
    assert_operator queries.size, :<=, 2,
      "Expected at most 2 SQL queries on the redirect hot path, got #{queries.size}:\n#{queries.join("\n")}"
  end

  test "redirect returns 429 after exceeding rate limit" do
    30.times do
      get link_redirect_path(@link.slug), headers: { "User-Agent" => "TestBrowser/1.0" }
      assert_response :success
    end

    get link_redirect_path(@link.slug), headers: { "User-Agent" => "TestBrowser/1.0" }
    assert_response :too_many_requests
    assert_includes response.body, "Too many requests"
  end

  test "rate-limited request does not enqueue a visit job" do
    30.times do
      get link_redirect_path(@link.slug), headers: { "User-Agent" => "TestBrowser/1.0" }
    end

    assert_no_enqueued_jobs(only: RecordVisitJob) do
      get link_redirect_path(@link.slug), headers: { "User-Agent" => "TestBrowser/1.0" }
    end
    assert_response :too_many_requests
  end

  test "crawler user agent does not enqueue a visit job" do
    assert_no_enqueued_jobs(only: RecordVisitJob) do
      get link_redirect_path(@link.slug), headers: { "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)" }
    end
    assert_response :success
  end

  test "redirect page HTML-escapes ampersands in href but not in the JS redirect" do
    @link.update_column(:url, "https://example.com/path?a=1&b=2")
    get link_redirect_path(@link.slug), headers: { "User-Agent" => "TestBrowser/1.0" }
    assert_response :success

    # href attributes are HTML-escaped; browsers decode &amp; back to & on navigation.
    assert_includes response.body, 'href="https://example.com/path?a=1&amp;b=2"'

    # The auto-redirect must not HTML-escape: a literal &amp; in the JS string breaks UTM params.
    assert_match(/window\.location\.replace\("https:\/\/example\.com\/path\?a=1(?:\\u0026|&)b=2"\)/, response.body)
    refute_match(/window\.location\.replace\("https:\/\/example\.com\/path\?a=1&amp;b=2"\)/, response.body)
  end

  # Authentication tests
  test "should redirect to login when not authenticated for show" do
    get workspace_link_path(@workspace, @link.slug)
    assert_redirected_to new_session_path
  end

  # Authorization tests for show
  test "owner can view link" do
    sign_in_as(@owner)
    get workspace_link_path(@workspace, @link.slug)
    assert_response :success
  end

  test "member can view link" do
    sign_in_as(@member)
    get workspace_link_path(@workspace, @link.slug)
    assert_response :success
  end

  test "non-member cannot view link" do
    non_member = User.create!(email: "nonmember@example.com", password: "password123")
    sign_in_as(non_member)

    get workspace_link_path(@workspace, @link.slug)
    assert_redirected_to dashboard_path
  end

  # Authorization tests for create
  test "member can create link" do
    sign_in_as(@member)

    assert_difference "Link.count", 1 do
      post workspace_links_path(@workspace)
    end

    assert_redirected_to workspace_link_path(@workspace, Link.last.slug)
  end

  test "non-member cannot create link" do
    non_member = User.create!(email: "nonmember@example.com", password: "password123")
    sign_in_as(non_member)

    assert_no_difference "Link.count" do
      post workspace_links_path(@workspace)
    end

    assert_redirected_to dashboard_path
  end

  # Authorization tests for update
  test "member can update link" do
    sign_in_as(@member)

    patch workspace_link_path(@workspace, @link.slug), params: { name: "Updated Name", url: "https://updated.com" }
    assert_redirected_to workspace_link_path(@workspace, @link.slug)

    @link.reload
    assert_equal "Updated Name", @link.name
  end

  test "non-member cannot update link" do
    non_member = User.create!(email: "nonmember@example.com", password: "password123")
    sign_in_as(non_member)
    original_name = @link.name

    patch workspace_link_path(@workspace, @link.slug), params: { name: "Should Not Update" }
    assert_redirected_to dashboard_path

    @link.reload
    assert_equal original_name, @link.name
  end

  # Authorization tests for destroy
  test "member can delete link" do
    sign_in_as(@member)

    assert_difference "Link.count", -1 do
      delete workspace_link_path(@workspace, @link.slug)
    end

    assert_redirected_to dashboard_path
  end

  test "non-member cannot delete link" do
    non_member = User.create!(email: "nonmember@example.com", password: "password123")
    sign_in_as(non_member)

    assert_no_difference "Link.count" do
      delete workspace_link_path(@workspace, @link.slug)
    end

    assert_redirected_to dashboard_path
  end

  test "member can queue social tag sync when cooldown elapsed" do
    sign_in_as(@member)
    get workspace_link_path(@workspace, @link.slug)

    social_tag = SocialTag.create!(link: @link, title: "Old", description: "D", url: @link.url)
    social_tag.update_column(:updated_at, (SocialTag::REFRESH_COOLDOWN + 1.minute).ago)

    assert_enqueued_with(job: SyncSocialTagJob, args: [ { slug: @link.slug } ]) do
      put social_tag_workspace_link_path(@workspace, @link.slug),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "turbo-stream", response.body
    social_tag.reload
    assert social_tag.updated_at > 1.minute.ago
  end

  test "member cannot queue social tag sync within cooldown" do
    sign_in_as(@member)
    get workspace_link_path(@workspace, @link.slug)

    social_tag = SocialTag.create!(link: @link, title: "Old", description: "D", url: @link.url)

    assert_no_enqueued_jobs(only: SyncSocialTagJob) do
      put social_tag_workspace_link_path(@workspace, @link.slug),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "turbo-stream", response.body
    assert_match "once every 5 minutes", response.body
  end

  test "social tag sync redirects with notice for html request" do
    sign_in_as(@member)
    get workspace_link_path(@workspace, @link.slug)

    social_tag = SocialTag.create!(link: @link, title: "Old", description: "D", url: @link.url)
    social_tag.update_column(:updated_at, (SocialTag::REFRESH_COOLDOWN + 1.minute).ago)

    assert_enqueued_with(job: SyncSocialTagJob) do
      put social_tag_workspace_link_path(@workspace, @link.slug),
        headers: { "Accept" => "text/html" }
    end

    assert_redirected_to workspace_link_path(@workspace, @link.slug)
    assert_equal "Social tag is being fetched and updated. This can take a few minutes to update the preview", flash[:notice]
  end

  test "should redirect to login when not authenticated for social_tag" do
    put social_tag_workspace_link_path(@workspace, @link.slug)
    assert_redirected_to new_session_path
  end

  test "non-member cannot sync social tag" do
    non_member = User.create!(email: "nonmember@example.com", password: "password123")
    SocialTag.create!(link: @link, title: "Old", description: "D", url: @link.url)
    sign_in_as(non_member)

    assert_no_enqueued_jobs(only: SyncSocialTagJob) do
      put social_tag_workspace_link_path(@workspace, @link.slug),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_redirected_to dashboard_path
  end

  private

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "password123" }
  end
end
