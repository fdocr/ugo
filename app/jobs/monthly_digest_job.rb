class MonthlyDigestJob < ApplicationJob
  queue_as :default

  def perform
    total_sent = 0

    Workspace.where(monthly_digest: true).find_each do |workspace|
      top_links = workspace.top_links_by_visits(since: 1.month.ago)
      next if top_links.empty?

      workspace.users.find_each do |user|
        WorkspaceDigestMailer.monthly_digest(
          user: user,
          workspace: workspace,
          top_links: top_links
        ).deliver_later

        total_sent += 1
      end
    end

    Rails.logger.info "MonthlyDigestJob: Enqueued #{total_sent} monthly digest emails"
  end
end
