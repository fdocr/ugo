class AddAdminScriptsToAppConfigs < ActiveRecord::Migration[8.1]
  def change
    add_column :app_configs, :admin_scripts, :text, null: false, default: ""
  end
end
