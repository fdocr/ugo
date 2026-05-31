module UiTour
  # Pre-configured logins keyed by symbol. A tour script declares
  # `use_session :admin` and the runner signs that user in once before any
  # scene runs (and signs out at the end of the script).
  module SessionPool
    SESSIONS = {
      admin:  -> { { email: Fixtures::ADMIN_EMAIL,  password: Fixtures::PASSWORD } },
      owner:  -> { { email: Fixtures::OWNER_EMAIL,  password: Fixtures::PASSWORD } },
      member: -> { { email: Fixtures::MEMBER_EMAIL, password: Fixtures::PASSWORD } }
    }.freeze

    def self.login(session, name)
      creds = SESSIONS.fetch(name) { raise ArgumentError, "Unknown session #{name.inspect}" }.call

      session.visit("/session/new")
      session.fill_in("Email", with: creds[:email])
      session.fill_in("Password", with: creds[:password])
      session.click_button("Sign in")

      # Wait for the redirect away from the login page. If the credentials were
      # rejected we'll still be on /session/new with a flash alert — surface
      # that loudly so tour authors don't get silent "logged out" screenshots.
      session.has_no_selector?("input[type=password]", wait: 5) ||
        raise("UI Tour login failed for #{name.inspect} (#{creds[:email]}): still on #{session.current_path}")
    end

    def self.logout(session)
      # Reset the browser session entirely (cookies, storage). Faster and more
      # reliable than driving the hamburger-menu sign out button.
      session.reset_session!
    end
  end
end
