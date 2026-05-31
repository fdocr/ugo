# Sign-in / sign-up auth surface. Sign-up is hidden in self-hosted mode where
# only the site admin provisions accounts.
Tour.script "Authentication", modes: [ :main_app ] do
  scene "Sign in form" do
    visit "/session/new"
    expect_text "Welcome back"
    snapshot
  end

  scene "Sign up form" do
    visit "/sign_up"
    expect_text "Create an account"
    snapshot
  end

  scene "Forgot password" do
    visit "/passwords/new"
    snapshot
  end

  scene "Sign in invalid credentials" do
    visit "/session/new"
    fill_in "Email", with: "nobody@example.com"
    fill_in "Password", with: "wrong-password"
    click_button "Sign in"
    snapshot caption: "Error flash on failed login"
  end
end
