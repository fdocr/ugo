class AddTrialEndsAtToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :trial_ends_at, :datetime
    add_index :workspaces, :trial_ends_at
  end
end
