# frozen_string_literal: true

require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "forgot password page omits turnstile widget when secret is not configured" do
    get new_password_path
    assert_response :success
    assert_no_match "cf-turnstile", response.body
  end

  test "forgot password page includes turnstile widget when configured on main app" do
    with_turnstile_keys(site: "1x00000000000000000000AA", secret: "1x0000000000000000000000000000000AA") do
      get new_password_path
      assert_response :success
      assert_match "cf-turnstile", response.body
      assert_match 'data-action="forgot_password"', response.body
    end
  end

  test "password reset request is blocked when turnstile verification fails" do
    user = users(:one)

    with_turnstile_keys(site: "2x00000000000000000000AB", secret: "2x0000000000000000000000000000000AA") do
      assert_no_enqueued_emails do
        post passwords_path, params: {
          email: user.email,
          "cf-turnstile-response" => "XXXX.DUMMY.TOKEN.XXXX"
        }
      end

      assert_redirected_to new_password_path
      assert_match "Verification failed", flash[:alert]
    end
  end

  test "password reset request succeeds when turnstile is configured and token is valid" do
    user = users(:one)

    with_turnstile_keys(site: "1x00000000000000000000AA", secret: "1x0000000000000000000000000000000AA") do
      assert_enqueued_emails 1 do
        post passwords_path, params: {
          email: user.email,
          "cf-turnstile-response" => "XXXX.DUMMY.TOKEN.XXXX"
        }
      end

      assert_redirected_to new_session_path
      assert_match "Password reset instructions sent", flash[:notice]
    end
  end

  test "password reset request without turnstile configured" do
    user = users(:one)

    assert_enqueued_emails 1 do
      post passwords_path, params: { email: user.email }
    end

    assert_redirected_to new_session_path
  end
end
