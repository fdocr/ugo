class RemoveSharedWorkspaceFromAppConfigs < ActiveRecord::Migration[8.1]
  def change
    remove_column :app_configs, :shared_workspace, :boolean, default: false, null: false
  end
end
