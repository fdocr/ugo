require "test_helper"

class BillingControllerTest < ActionDispatch::IntegrationTest
  setup do
    setup_app_config_as_main_app!
    @admin = users(:one)
    @workspace = Workspace.create!(name: "Billing WS", user: @admin, plan: :basic)
    @subscription = @workspace.create_subscription!(
      status: :active,
      polar_subscription_id: "sub_1",
      polar_customer_id: "cus_1",
      polar_product_id: "prod_basic",
      amount_cents: 900,
      currency: "USD",
      customer_email: @admin.email
    )
    sign_in @admin
  end

  test "manage redirects to the Polar customer portal" do
    captured = nil
    stub_polar_api(:create_customer_session, ->(**kwargs) {
      captured = kwargs
      OpenStruct.new(customer_portal_url: "https://polar.sh/portal/abc")
    }) do
      get manage_workspace_billing_path(@workspace)
    end

    assert_equal "cus_1", captured[:customer_id]
    assert_redirected_to "https://polar.sh/portal/abc"
  end

  test "manage requires a Polar customer id" do
    @subscription.update!(polar_customer_id: nil)
    get manage_workspace_billing_path(@workspace)
    assert_redirected_to workspace_billing_path(@workspace)
    assert_match(/no billing account/i, flash[:alert])
  end

  test "cancel revokes the Polar subscription and downgrades the workspace" do
    revoked = nil
    stub_polar_api(:revoke_subscription, ->(id) { revoked = id; true }) do
      delete cancel_workspace_billing_path(@workspace)
    end

    assert_equal "sub_1", revoked
    assert_redirected_to workspace_billing_path(@workspace)
    assert @subscription.reload.cancelled?
    assert_equal "free", @workspace.reload.plan
  end

  test "cancel does not downgrade when Polar revoke fails" do
    stub_polar_api(:revoke_subscription, ->(*) { raise PolarApi::Error, "nope" }) do
      delete cancel_workspace_billing_path(@workspace)
    end

    assert_redirected_to workspace_billing_path(@workspace)
    assert_match(/unable to cancel/i, flash[:alert])
    assert @subscription.reload.active?
    assert_equal "basic", @workspace.reload.plan
  end

  test "self-hosted installations cannot open billing" do
    setup_app_config_as_self_hosted!
    get workspace_billing_path(@workspace)
    assert_redirected_to workspace_path(@workspace)
  end

  private

  def sign_in(user)
    post session_path, params: { email: user.email, password: "password123" }
  end
end
