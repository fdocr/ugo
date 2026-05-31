class AddDomainsToWorkspaces < ActiveRecord::Migration[8.0]
  def change
    add_column :workspaces, :domain, :string
    add_index :workspaces, :domain, unique: true
  end
end
