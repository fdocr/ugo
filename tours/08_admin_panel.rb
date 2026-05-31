# Site-admin only screens.
Tour.script "Admin panel" do
  use_session :admin

  scene "Admin dashboard" do
    visit "/admin"
    snapshot full_page: true, caption: "Site-wide stats: users, workspaces, links, visits"
  end

  scene "Admin workspaces list" do
    visit "/admin/workspaces"
    snapshot full_page: true
  end

  scene "Admin links list" do
    visit "/admin/links"
    snapshot full_page: true
  end

  scene "Admin settings" do
    visit "/admin/settings"
    snapshot full_page: true, caption: "App config: domain, SMTP, branding"
  end

  scene "Admin – new user form" do
    visit "/admin/users/new"
    snapshot
  end
end
