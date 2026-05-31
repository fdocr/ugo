# Create → view → edit a link, including analytics.
Tour.script "Link lifecycle" do
  use_session :admin

  scene "New link form" do
    visit "/links/new"
    expect_text "URL"
    snapshot full_page: true
  end

  scene "Existing link – Spring Campaign" do
    workspace = Workspace.find_by!(name: "Acme Marketing")
    link = workspace.links.find_by!(slug: "spring-2026")
    visit "/workspace/#{workspace.id}/links/#{link.slug}"
    snapshot full_page: true, caption: "Link details with QR code, analytics tabs"
  end

  scene "Link edit form" do
    workspace = Workspace.find_by!(name: "Acme Marketing")
    link = workspace.links.find_by!(slug: "spring-2026")
    visit "/workspace/#{workspace.id}/links/#{link.slug}/edit"
    snapshot full_page: true
  end

  scene "Link visits feed" do
    workspace = Workspace.find_by!(name: "Acme Marketing")
    link = workspace.links.find_by!(slug: "spring-2026")
    visit "/workspace/#{workspace.id}/links/#{link.slug}/visits"
    snapshot full_page: true, caption: "Per-visit details with referrer / device / country"
  end

  scene "Mobile link analytics" do
    workspace = Workspace.find_by!(name: "Acme Marketing")
    link = workspace.links.find_by!(slug: "spring-2026")
    visit "/workspace/#{workspace.id}/links/#{link.slug}"
    snapshot viewport: :mobile, full_page: true
  end
end
