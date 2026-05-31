class WorkspaceDigestMailer < ApplicationMailer
  def weekly_digest(user:, workspace:, top_links:)
    @user = user
    @workspace = workspace
    @top_links = top_links
    @period = "#{1.week.ago.strftime('%b %d')} - #{Time.current.strftime('%b %d, %Y')}"
    @dashboard_url = dashboard_url
    @workspace_url = workspace_url(workspace.id)

    mail(
      to: @user.email,
      subject: "Weekly report for #{@workspace.name}"
    )
  end

  def monthly_digest(user:, workspace:, top_links:)
    @user = user
    @workspace = workspace
    @top_links = top_links
    @period = 1.month.ago.strftime("%B %Y")
    @dashboard_url = dashboard_url
    @workspace_url = workspace_url(workspace.id)

    mail(
      to: @user.email,
      subject: "Monthly report for #{@workspace.name}"
    )
  end
end
