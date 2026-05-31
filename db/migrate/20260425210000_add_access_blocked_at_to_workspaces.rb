class AddAccessBlockedAtToWorkspaces < ActiveRecord::Migration[8.1]
  # Denormalized "is this workspace currently locked out?" flag, written by
  # Workspace/Subscription callbacks and the RefreshWorkspaceAccessJob sweeper.
  # The link redirect hot path reads this column instead of recomputing billing
  # state (subscription association + AppConfig.self_hosted? + trial window) on
  # every click.
  def up
    add_column :workspaces, :access_blocked_at, :datetime
    add_index :workspaces, :access_blocked_at

    # Backfill via raw SQL so this migration stays decoupled from model code.
    # Rules: dedicated workspaces are never blocked; workspaces with an active
    # or past_due subscription are not blocked; otherwise blocked iff the
    # trial has ended (or was never granted, e.g. legacy free workspaces).
    execute(<<~SQL)
      UPDATE workspaces
      SET access_blocked_at = CURRENT_TIMESTAMP
      WHERE plan != 2
        AND id NOT IN (
          SELECT workspace_id FROM subscriptions WHERE status IN (0, 1)
        )
        AND (trial_ends_at IS NULL OR trial_ends_at <= CURRENT_TIMESTAMP)
    SQL
  end

  def down
    remove_index :workspaces, :access_blocked_at
    remove_column :workspaces, :access_blocked_at
  end
end
