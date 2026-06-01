class RemoveHoneybadgerApiKeyFromAppConfigs < ActiveRecord::Migration[8.1]
  def change
    remove_column :app_configs, :honeybadger_api_key, :string, default: ""
  end
end
