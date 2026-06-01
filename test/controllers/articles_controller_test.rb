require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    setup_app_config_as_main_app!
  end

  test "open beta article is accessible without authentication" do
    get open_beta_article_path
    assert_response :success
    assert_select "h1", text: "Unlimited trial during open beta"
    assert_select "a[href='#{sign_up_path}']", text: "Get Started Now"
    assert_select "a[href='#{pricing_path}']", text: "View Hosted Plans"
  end

  test "open beta article shows dashboard button for authenticated users" do
    sign_in_as(users(:one))
    get open_beta_article_path
    assert_response :success
    assert_select "a[href='#{dashboard_path}']", text: "Go to Dashboard"
  end

  test "open beta article redirects on self-hosted" do
    setup_app_config_as_self_hosted!
    get open_beta_article_path
    assert_redirected_to root_path
  end

  private

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "password123" }
  end
end
