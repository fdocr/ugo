# Public, unauthenticated marketing pages. Main-app only — self-hosted mode
# does not expose pricing/about/privacy without an authenticated user.
Tour.script "Logged-out marketing", modes: [ :main_app ] do
  scene "Home" do
    visit "/"
    snapshot full_page: true
  end

  scene "Pricing" do
    visit "/pricing"
    snapshot full_page: true
  end

  scene "About" do
    visit "/about"
    snapshot full_page: true
  end

  scene "Privacy policy" do
    visit "/privacy"
    snapshot full_page: true
  end

  scene "Mobile home with menu open" do
    visit "/"
    find('button[name="menu"]').click
    snapshot viewport: :mobile, full_page: false, caption: "Mobile nav drawer for unauthenticated users"
  end
end
