class CleanupVisitsJob < ApplicationJob
  queue_as :default

  def perform
    cleanup_free_workspace_visits
    cleanup_paid_workspace_visits
  end

  private

  def cleanup_free_workspace_visits
    cutoff_date = 1.month.ago

    total_deleted = 0
    Workspace.free.find_each do |workspace|
      workspace.links.find_each do |link|
        deleted_count = link.visits.where("timestamp < ?", cutoff_date).delete_all
        total_deleted += deleted_count
      end
      next if total_deleted.zero?

      Rails.logger.info "CleanupVisitsJob: Deleted #{total_deleted} visits older than 1 month for free workspace '#{workspace.name}' (#{workspace.id})"
    end
  end

  def cleanup_paid_workspace_visits
    cutoff_date = 3.months.ago

    Workspace.where(plan: [ :basic, :growth ]).find_each do |workspace|
      total_deleted = 0
      workspace.links.find_each do |link|
        deleted_count = link.visits.where("timestamp < ?", cutoff_date).delete_all
        total_deleted += deleted_count
      end
      next if total_deleted.zero?

      Rails.logger.info "CleanupVisitsJob: Deleted #{total_deleted} visits older than 3 months for #{workspace.plan} workspace '#{workspace.name}' (#{workspace.id})"
    end
  end
end
