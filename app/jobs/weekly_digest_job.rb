class WeeklyDigestJob < ApplicationJob
  queue_as :default

  def perform
    total_sent = 0

    Workspace.where(weekly_digest: true).where.not(plan: :free).find_each do |workspace|
      top_links = workspace.top_links_by_visits(since: 1.week.ago)
      next if top_links.empty?

      workspace.users.find_each do |user|
        WorkspaceDigestMailer.weekly_digest(
          user: user,
          workspace: workspace,
          top_links: top_links
        ).deliver_later

        total_sent += 1
      end
    end

    Rails.logger.info "WeeklyDigestJob: Enqueued #{total_sent} weekly digest emails"
  end
end
