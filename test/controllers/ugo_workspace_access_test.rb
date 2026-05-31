require "test_helper"

class UgoWorkspaceAccessTest < ActionDispatch::IntegrationTest
  setup do
    setup_app_config_as_main_app!
    @admin = users(:one)
    @member = users(:two)

    @workspace = Workspace.create!(name: "Ugo trial workspace", user: @admin, plan: :free)
    @workspace.memberships.create!(user: @member, role: :member)
    @link = Link.create!(name: "Test", slug: "ugo-#{SecureRandom.hex(3)}", workspace: @workspace, url: "https://example.com")
  end

  # -- Trial active: access allowed --

  test "admin can view workspace during trial" do
    sign_in @admin
    get workspace_path(@workspace)
    assert_response :success
  end

  test "member can view link during trial" do
    sign_in @member
    get workspace_link_path(@workspace, @link.slug)
    assert_response :success
  end

  # -- Trial expired, no subscription: hard stop --

  test "admin is redirected to billing when trial expired on workspace show" do
    expire_trial!
    sign_in @admin

    get workspace_path(@workspace)
    assert_redirected_to workspace_billing_path(@workspace)
    assert_match(/trial has ended/i, flash[:alert])
  end

  test "member is redirected to dashboard when trial expired on workspace show" do
    expire_trial!
    sign_in @member

    get workspace_path(@workspace)
    assert_redirected_to dashboard_path
    assert_match(/active subscription/i, flash[:alert])
  end

  test "admin is redirected to billing when trial expired on link show" do
    expire_trial!
    sign_in @admin

    get workspace_link_path(@workspace, @link.slug)
    assert_redirected_to workspace_billing_path(@workspace)
  end

  test "admin is redirected to billing when trial expired on link create" do
    expire_trial!
    sign_in @admin

    assert_no_difference "Link.count" do
      post workspace_links_path(@workspace)
    end
    assert_redirected_to workspace_billing_path(@workspace)
  end

  # -- Billing and checkout remain accessible when disabled --

  test "admin can access billing when trial expired" do
    expire_trial!
    sign_in @admin

    get workspace_billing_path(@workspace)
    assert_response :success
  end

  # -- Paid subscription: access restored --

  test "admin can view workspace with active subscription after trial expired" do
    expire_trial!
    @workspace.create_subscription!(
      status: :active,
      amount_cents: 900,
      currency: "USD"
    )
    @workspace.update!(plan: :basic)

    sign_in @admin
    get workspace_path(@workspace)
    assert_response :success
  end

  # -- Self-hosted: never enforced --

  test "self-hosted workspace is never blocked" do
    setup_app_config_as_self_hosted!
    ws = Workspace.create!(name: "Self Hosted", user: @admin, plan: :free)
    Link.create!(name: "SH Link", slug: "sh-#{SecureRandom.hex(3)}", workspace: ws, url: "https://example.com")

    sign_in @admin
    get workspace_path(ws)
    assert_response :success
  end

  private

  def expire_trial!
    @workspace.update!(trial_ends_at: 1.day.ago)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: "password123" }
  end
end
