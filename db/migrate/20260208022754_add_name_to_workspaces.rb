class AddNameToWorkspaces < ActiveRecord::Migration[8.1]
  def change
    add_column :workspaces, :name, :string, null: false, default: "Default"
    add_index :workspaces, :name
  end
end
