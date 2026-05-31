# Preview all emails at http://localhost:3000/rails/mailers/workspace_digest_mailer
class WorkspaceDigestMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/workspace_digest_mailer/weekly_digest
  def weekly_digest
    workspace = Workspace.first
    user = workspace.users.first
    top_links = workspace.top_links_by_visits(since: 1.week.ago)

    WorkspaceDigestMailer.weekly_digest(
      user: user,
      workspace: workspace,
      top_links: top_links
    )
  end

  # Preview this email at http://localhost:3000/rails/mailers/workspace_digest_mailer/monthly_digest
  def monthly_digest
    workspace = Workspace.first
    user = workspace.users.first
    top_links = workspace.top_links_by_visits(since: 1.month.ago)

    WorkspaceDigestMailer.monthly_digest(
      user: user,
      workspace: workspace,
      top_links: top_links
    )
  end
end
