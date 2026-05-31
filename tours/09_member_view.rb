# Same workspace from the perspective of a non-admin member: pending
# invitations on the dashboard, restricted action buttons in the workspace.
Tour.script "Member perspective" do
  use_session :member

  scene "Member dashboard" do
    visit "/dashboard"
    snapshot full_page: true, caption: "Member sees workspaces they belong to but no admin actions"
  end

  scene "Member viewing a shared workspace" do
    workspace = Workspace.find_by!(name: "Acme Marketing")
    visit "/workspace/#{workspace.id}"
    snapshot full_page: true, caption: "Read-write workspace view without admin controls"
  end
end
