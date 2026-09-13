require "test_helper"

class CheckoutControllerTest < ActionDispatch::IntegrationTest
  setup do
    setup_app_config_as_main_app!
    AppConfig.shared.update!(polar_basic_product_id: "prod_basic", polar_growth_product_id: "prod_growth")
    @admin = users(:one)
    @workspace = Workspace.create!(name: "Checkout WS", user: @admin, plan: :free)
    sign_in @admin
  end

  test "creates a Polar checkout with products and redirects to the session URL" do
    captured = nil
    stub_polar_api(:create_checkout, ->(**kwargs) {
      captured = kwargs
      OpenStruct.new(url: "https://buy.polar.sh/session")
    }) do
      get new_workspace_checkout_path(@workspace, plan: "growth")
    end

    assert_redirected_to "https://buy.polar.sh/session"
    assert_equal [ "prod_growth" ], captured[:products]
    assert_equal @admin.email, captured[:customer_email]
    assert_equal @workspace.id.to_s, captured[:metadata][:workspace_id]
    assert_includes captured[:success_url], workspace_checkout_path(@workspace)
  end

  test "redirects to billing when Polar is not configured" do
    AppConfig.shared.update!(polar_basic_product_id: "", polar_growth_product_id: "")

    get new_workspace_checkout_path(@workspace, plan: "basic")
    assert_redirected_to workspace_billing_path(@workspace)
    assert_match(/not configured/i, flash[:alert])
  end

  test "redirects to billing when Polar checkout fails" do
    stub_polar_api(:create_checkout, ->(**) { raise PolarApi::Error, "boom" }) do
      get new_workspace_checkout_path(@workspace, plan: "basic")
    end

    assert_redirected_to workspace_billing_path(@workspace)
    assert_match(/temporarily unavailable/i, flash[:alert])
  end

  test "rejects an invalid plan" do
    get new_workspace_checkout_path(@workspace, plan: "enterprise")
    assert_redirected_to workspace_billing_path(@workspace)
    assert_match(/invalid plan/i, flash[:alert])
  end

  test "redirects if the workspace is already subscribed" do
    @workspace.create_subscription!(
      status: :active,
      polar_subscription_id: "sub_1",
      amount_cents: 900,
      currency: "USD"
    )

    get new_workspace_checkout_path(@workspace, plan: "basic")
    assert_redirected_to workspace_billing_path(@workspace)
    assert_match(/already have an active subscription/i, flash[:notice])
  end

  test "self-hosted installations cannot start checkout" do
    setup_app_config_as_self_hosted!
    get new_workspace_checkout_path(@workspace, plan: "basic")
    assert_redirected_to workspace_path(@workspace)
  end

  private

  def sign_in(user)
    post session_path, params: { email: user.email, password: "password123" }
  end
end
