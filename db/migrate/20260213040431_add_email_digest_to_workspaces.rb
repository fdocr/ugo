class AddEmailDigestToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :weekly_digest, :boolean, default: false, null: false
    add_column :workspaces, :monthly_digest, :boolean, default: false, null: false
  end
end
