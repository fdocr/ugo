class RemoveSlugFromWorkspaces < ActiveRecord::Migration[8.1]
  def change
    remove_index :workspaces, :slug
    remove_column :workspaces, :slug, :string
  end
end
