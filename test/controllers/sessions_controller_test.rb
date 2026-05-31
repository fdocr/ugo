require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "banned user cannot sign in" do
    user = User.create!(email: "banned@example.com", password: "password123", banned_at: Time.current)

    post session_path, params: { email: user.email, password: "password123" }

    assert_redirected_to new_session_path
    assert_match "Your account has been suspended", flash[:alert]
    assert_match "fernando@fdo.cr", flash[:alert]
  end

  test "valid user can sign in" do
    user = User.create!(email: "validuser@example.com", password: "password123")

    post session_path, params: { email: user.email, password: "password123" }

    assert_redirected_to dashboard_path
    assert_match "Successfully signed in", flash[:notice]
  end

  test "invalid credentials show error" do
    user = User.create!(email: "validuser@example.com", password: "password123")

    post session_path, params: { email: user.email, password: "wrongpassword" }

    assert_redirected_to new_session_path
    assert_match "Invalid email or password", flash[:alert]
  end

  test "expired session is rejected and destroyed" do
    user = User.create!(email: "expired@example.com", password: "password123")
    post session_path, params: { email: user.email, password: "password123" }

    session = user.sessions.last
    session.update_column(:last_active_at, 31.days.ago)

    get dashboard_path
    assert_redirected_to new_session_path
    assert_nil Session.find_by(id: session.id)
  end

  test "active session is not rejected" do
    user = User.create!(email: "active@example.com", password: "password123")
    post session_path, params: { email: user.email, password: "password123" }

    session = user.sessions.last
    assert_not_nil session.last_active_at

    get dashboard_path
    assert_response :success
  end
end
