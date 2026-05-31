class AddPolarAndHoneybadgerToAppConfigs < ActiveRecord::Migration[8.1]
  def change
    add_column :app_configs, :polar_access_token, :string, default: ""
    add_column :app_configs, :polar_webhook_secret, :string, default: ""
    add_column :app_configs, :polar_basic_product_id, :string, default: ""
    add_column :app_configs, :polar_growth_product_id, :string, default: ""
    add_column :app_configs, :polar_sandbox, :boolean, default: false
    add_column :app_configs, :honeybadger_api_key, :string, default: ""
  end
end
