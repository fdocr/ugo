class AddSharedWorkspaceToAppConfigs < ActiveRecord::Migration[8.1]
  def change
    add_column :app_configs, :shared_workspace, :boolean, default: true, null: false
  end
end
