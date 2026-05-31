# Workspace overview, settings, member list, invitations.
Tour.script "Workspace (trial)" do
  use_session :admin

  scene "Workspace overview – Acme Marketing (trial)" do
    workspace = Workspace.find_by!(name: "Acme Marketing")
    visit "/workspace/#{workspace.id}"
    expect_text "Acme Marketing"
    snapshot full_page: true, caption: "Workspace dashboard with active trial banner"
  end

  scene "Workspace settings" do
    workspace = Workspace.find_by!(name: "Acme Marketing")
    visit "/workspace/#{workspace.id}/edit"
    snapshot full_page: true, caption: "Workspace settings: rename, weekly/monthly digests, members"
  end

  scene "Mobile workspace overview" do
    workspace = Workspace.find_by!(name: "Acme Marketing")
    visit "/workspace/#{workspace.id}"
    snapshot viewport: :mobile, full_page: true
  end
end
