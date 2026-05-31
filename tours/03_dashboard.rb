# Authenticated dashboard for an admin with several workspaces in different
# billing states.
Tour.script "Dashboard (admin)" do
  use_session :admin

  scene "Personal dashboard" do
    visit "/dashboard"
    expect_text "Workspaces"
    snapshot full_page: true
  end

  scene "Account – change password" do
    visit "/account/password"
    snapshot
  end

  scene "Mobile dashboard with menu open" do
    visit "/dashboard"
    find('button[name="menu"]').click
    snapshot viewport: :mobile, full_page: false, caption: "Authenticated mobile nav with admin links"
  end
end
