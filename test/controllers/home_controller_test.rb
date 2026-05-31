require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  # Index page tests
  test "index page is accessible without authentication" do
    get root_path
    assert_response :success
  end

  test "index page shows get started button for unauthenticated users" do
    get root_path
    assert_response :success
    assert_select "a[href='#{sign_up_path}']", text: "Get Started Now"
  end

  test "index page shows dashboard button for authenticated users" do
    sign_in_as(users(:one))
    get root_path
    assert_response :success
    assert_select "a[href='#{dashboard_path}']", text: "Go to Dashboard"
  end

  # About page tests
  test "about page is accessible without authentication" do
    get about_path
    assert_response :success
  end

  # Privacy page tests
  test "privacy page is accessible without authentication" do
    get privacy_path
    assert_response :success
  end

  # Pricing page tests
  test "pricing page is accessible without authentication" do
    get pricing_path
    assert_response :success
  end

  test "pricing page shows plan cards" do
    get pricing_path
    assert_response :success
    assert_select "h3", text: "Basic"
    assert_select "h3", text: "Growth"
    assert_select "h3", text: "Dedicated"
  end

  test "index page highlights deep linking feature" do
    get root_path
    assert_response :success
    assert_select "h3", text: "Deep Linking"
    assert_select "h3", text: "QR Codes", count: 0
  end

  test "pricing page lists deep linking on dedicated only" do
    get pricing_path
    assert_response :success
    basic_and_growth, dedicated_and_rest = response.body.split("<!-- Dedicated Plan -->", 2)
    assert basic_and_growth
    assert dedicated_and_rest
    assert_no_match(/Deep linking into native apps/, basic_and_growth)
    assert_match(/Deep linking into native apps/, dedicated_and_rest)
  end

  test "pricing page shows get started button for unauthenticated users" do
    get pricing_path
    assert_response :success
    assert_select "a[href='#{sign_up_path}']", minimum: 1
  end

  test "pricing page shows dashboard button for authenticated users" do
    sign_in_as(users(:one))
    get pricing_path
    assert_response :success
    assert_select "a[href='#{dashboard_path}']", minimum: 1
  end

  # Dashboard page tests
  test "dashboard page requires authentication" do
    get dashboard_path
    assert_redirected_to new_session_path
  end

  test "dashboard page is accessible for authenticated users" do
    sign_in_as(users(:one))
    get dashboard_path
    assert_response :success
  end

  # -- CSP header --

  test "responses include a Content-Security-Policy-Report-Only header" do
    get root_path
    csp = response.headers["Content-Security-Policy-Report-Only"]
    assert csp.present?, "CSP header should be present"
    assert_match "default-src 'self'", csp
    assert_match "script-src 'self'", csp
    assert_match "object-src 'none'", csp
  end

  # -- Self-hosted behavior --

  test "self-hosted index shows sign-in page for unauthenticated users" do
    setup_app_config_as_self_hosted!

    get root_path
    assert_response :success
    assert_select "a[href='#{new_session_path}']", text: "Sign In"
  end

  test "self-hosted index redirects authenticated users to dashboard" do
    setup_app_config_as_self_hosted!
    sign_in_as(users(:one))

    get root_path
    assert_redirected_to dashboard_path
  end

  test "self-hosted pricing redirects to root" do
    setup_app_config_as_self_hosted!

    get pricing_path
    assert_redirected_to root_path
  end

  private

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "password123" }
  end
end
