# Periodic sweeper that keeps the denormalized `workspaces.access_blocked_at`
# column in sync for state changes that aren't event-driven — chiefly trial
# expiry, where "time passing" is the trigger and there is no model save to
# hook into. Subscription create/update/destroy and explicit workspace plan or
# trial_ends_at changes already call `Workspace#recompute_access_blocked!`
# directly; this job is the safety net.
class RefreshWorkspaceAccessJob < ApplicationJob
  queue_as :default

  def perform
    return if AppConfig.self_hosted?

    # 1) Trials that just ran out: not currently flagged but should be.
    Workspace
      .where(access_blocked_at: nil)
      .where.not(plan: :dedicated)
      .where("trial_ends_at IS NOT NULL AND trial_ends_at <= ?", Time.current)
      .find_each(&:recompute_access_blocked!)

    # 2) Currently-flagged workspaces whose situation may have changed (manual
    # subscription tweaks via console, missed webhook, extended trial, etc.).
    # Bounded scan, recomputation is idempotent and cheap.
    Workspace
      .where.not(access_blocked_at: nil)
      .where.not(plan: :dedicated)
      .find_each(&:recompute_access_blocked!)
  end
end
