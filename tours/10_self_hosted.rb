# Self-hosted-mode-specific UI: the home view differs (no marketing site,
# straight to the sign-in CTA), workspaces are dedicated by default, and the
# billing pages are unreachable. The setup wizard is also self-hosted-only
# (the fixtures already mark setup as completed, but we visit the form
# explicitly by clearing the flag for one screenshot).
Tour.script "Self-hosted home + sign in", modes: [ :self_hosted ] do
  scene "Self-hosted landing (logged out)" do
    visit "/"
    snapshot full_page: true, caption: "Self-hosted home: branded sign-in card"
  end

  scene "Sign in form (self-hosted branding)" do
    visit "/session/new"
    snapshot
  end
end

Tour.script "Self-hosted dashboard", modes: [ :self_hosted ] do
  use_session :admin

  scene "Dashboard – dedicated workspaces" do
    visit "/dashboard"
    snapshot full_page: true, caption: "All workspaces are dedicated; no trial banners"
  end

  scene "Workspace overview" do
    workspace = Workspace.find_by!(name: "Acme Marketing")
    visit "/workspace/#{workspace.id}"
    snapshot full_page: true
  end

  scene "Admin settings" do
    visit "/admin/settings"
    snapshot full_page: true, caption: "Self-hosted admin: domain, branding, SMTP"
  end
end

Tour.script "Self-hosted setup wizard", modes: [ :self_hosted ] do
  scene "Setup wizard" do
    AppConfig.shared.update!(setup_completed: false)
    AppConfig.send(:reset_caches!)
    visit "/setup"
    snapshot full_page: true, caption: "First-run setup wizard (only seen before setup_completed)"
  ensure
    AppConfig.shared.update!(setup_completed: true)
    AppConfig.send(:reset_caches!)
  end
end
