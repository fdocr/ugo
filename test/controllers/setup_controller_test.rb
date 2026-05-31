# frozen_string_literal: true

require "test_helper"

class SetupControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Reset AppConfig to "not yet set up" state
    AppConfig.shared.update!(setup_completed: false, setup_code: "test-setup-code")
  end

  teardown do
    # Restore main-app state for other tests
    setup_app_config_as_main_app!
  end

  # -- GET /setup --

  test "setup page is accessible when setup not completed" do
    get setup_path
    assert_response :success
  end

  test "setup page redirects to root when setup already completed" do
    AppConfig.shared.update!(setup_completed: true)

    get setup_path
    assert_redirected_to root_path
  end

  test "setup page generates a setup code if blank" do
    AppConfig.shared.update!(setup_code: "")

    get setup_path
    assert_response :success

    AppConfig.shared.reload
    assert AppConfig.shared.setup_code.present?, "Setup code should be generated"
  end

  # -- POST /setup with invalid setup code --

  test "create rejects invalid setup code" do
    post setup_path, params: {
      setup_code: "wrong-code",
      app_name: "My App",
      app_domain: "example.com",
      admin_email: "admin@example.com",
      admin_password: "password123",
      admin_password_confirmation: "password123"
    }

    assert_redirected_to setup_path
    assert_match "Invalid setup code", flash[:alert]
  end

  # -- POST /setup with valid params (self-hosted) --

  test "create with non-matching domain creates dedicated workspace" do
    assert_difference "User.count", 1 do
      assert_difference "Workspace.count", 1 do
        post setup_path, params: {
          setup_code: "test-setup-code",
          app_name: "Self Hosted App",
          app_domain: "links.mycompany.com",
          admin_email: "admin@mycompany.com",
          admin_password: "password123",
          admin_password_confirmation: "password123"
        }
      end
    end

    assert_redirected_to dashboard_path
    assert_match "Setup completed", flash[:notice]

    # Verify config was saved
    config = AppConfig.shared.reload
    assert_equal "Self Hosted App", config.app_name
    assert_equal "links.mycompany.com", config.app_domain
    assert config.setup_completed

    # Verify user was created as site admin
    user = User.find_by(email: "admin@mycompany.com")
    assert user.site_admin?

    # Verify workspace plan is dedicated (self-hosted)
    workspace = user.workspaces.first
    assert workspace.dedicated?, "Self-hosted setup should create dedicated workspace"
  end

  # -- POST /setup with valid params (main app) --

  test "create with matching domain creates free workspace" do
    assert_difference "User.count", 1 do
      assert_difference "Workspace.count", 1 do
        post setup_path, params: {
          setup_code: "test-setup-code",
          app_name: "ugo",
          app_domain: "ugo.cr",
          admin_email: "admin@ugo.cr",
          admin_password: "password123",
          admin_password_confirmation: "password123"
        }
      end
    end

    assert_redirected_to dashboard_path

    # Verify workspace plan is free (main app)
    user = User.find_by(email: "admin@ugo.cr")
    workspace = user.workspaces.first
    assert workspace.dedicated?, "Main app setup should create dedicated workspace"
  end

  # -- POST /setup with SMTP settings --

  test "create saves SMTP settings when provided" do
    post setup_path, params: {
      setup_code: "test-setup-code",
      app_name: "My App",
      app_domain: "example.com",
      smtp_address: "smtp.example.com",
      smtp_port: "465",
      smtp_username: "user@example.com",
      smtp_password: "smtp-secret",
      smtp_from_email: "noreply@example.com",
      admin_email: "admin@example.com",
      admin_password: "password123",
      admin_password_confirmation: "password123"
    }

    assert_redirected_to dashboard_path

    config = AppConfig.shared.reload
    assert_equal "smtp.example.com", config.smtp_address
    assert_equal 465, config.smtp_port
    assert_equal "user@example.com", config.smtp_username
    assert_equal "noreply@example.com", config.smtp_from_email
  end

  # -- POST /setup with invalid user params --

  test "create fails with missing admin email" do
    assert_no_difference "User.count" do
      post setup_path, params: {
        setup_code: "test-setup-code",
        app_name: "My App",
        app_domain: "example.com",
        admin_email: "",
        admin_password: "password123",
        admin_password_confirmation: "password123"
      }
    end

    assert_redirected_to setup_path
    assert_match "Setup failed", flash[:alert]
  end

  test "create fails with mismatched passwords" do
    assert_no_difference "User.count" do
      post setup_path, params: {
        setup_code: "test-setup-code",
        app_name: "My App",
        app_domain: "example.com",
        admin_email: "admin@example.com",
        admin_password: "password123",
        admin_password_confirmation: "different456"
      }
    end

    assert_redirected_to setup_path
    assert_match "Setup failed", flash[:alert]
  end
end
