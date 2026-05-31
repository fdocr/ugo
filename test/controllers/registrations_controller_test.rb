# frozen_string_literal: true

require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  # -- Main app (registration enabled) --

  test "sign up page is accessible on main app" do
    get sign_up_path
    assert_response :success
  end

  test "user can register on main app" do
    email = "newuser-#{SecureRandom.hex(4)}@example.com"
    assert_difference "User.count", 1 do
      post sign_up_path, params: {
        email: email,
        password: "password123",
        password_confirmation: "password123"
      }
    end

    assert_redirected_to dashboard_path

    user = User.find_by!(email: email)
    workspace = user.owned_workspaces.sole
    assert workspace.trial_ends_at.present?
    assert workspace.trial?
  end

  # -- Self-hosted (registration disabled) --

  test "sign up page is blocked on self-hosted" do
    setup_app_config_as_self_hosted!

    get sign_up_path
    assert_redirected_to root_path
    assert_match "registration is disabled", flash[:alert]
  end

  test "registration POST is blocked on self-hosted" do
    setup_app_config_as_self_hosted!

    assert_no_difference "User.count" do
      post sign_up_path, params: {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    end

    assert_redirected_to root_path
  end

  # -- Already authenticated --

  test "authenticated user is redirected from sign up" do
    sign_in_as(users(:one))

    get sign_up_path
    assert_redirected_to root_path
  end

  test "sign up page omits turnstile widget when secret is not configured" do
    get sign_up_path
    assert_response :success
    assert_no_match "cf-turnstile", response.body
  end

  test "sign up page includes turnstile widget when configured on main app" do
    with_turnstile_keys(site: "1x00000000000000000000AA", secret: "1x0000000000000000000000000000000AA") do
      get sign_up_path
      assert_response :success
      assert_match "cf-turnstile", response.body
    end
  end

  test "registration is blocked when turnstile verification fails" do
    with_turnstile_keys(site: "2x00000000000000000000AB", secret: "2x0000000000000000000000000000000AA") do
      email = "blocked-#{SecureRandom.hex(4)}@example.com"
      assert_no_difference "User.count" do
        post sign_up_path, params: {
          email: email,
          password: "password123",
          password_confirmation: "password123",
          "cf-turnstile-response" => "XXXX.DUMMY.TOKEN.XXXX"
        }
      end

      assert_redirected_to sign_up_path
      assert_match "Verification failed", flash[:alert]
    end
  end

  test "user can register when turnstile is configured and token is valid" do
    with_turnstile_keys(site: "1x00000000000000000000AA", secret: "1x0000000000000000000000000000000AA") do
      email = "turnstile-#{SecureRandom.hex(4)}@example.com"
      assert_difference "User.count", 1 do
        post sign_up_path, params: {
          email: email,
          password: "password123",
          password_confirmation: "password123",
          "cf-turnstile-response" => "XXXX.DUMMY.TOKEN.XXXX"
        }
      end

      assert_redirected_to dashboard_path
    end
  end

  private

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "password123" }
  end
end
