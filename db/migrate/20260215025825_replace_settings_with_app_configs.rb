class ReplaceSettingsWithAppConfigs < ActiveRecord::Migration[8.1]
  def up
    create_table :app_configs do |t|
      t.string :app_name, default: "ugo", null: false
      t.string :app_domain, default: "", null: false
      t.boolean :setup_completed, default: false, null: false
      t.string :setup_code, default: ""
      t.string :admin_api_key, default: "admin-secret-key"
      t.string :smtp_address, default: ""
      t.integer :smtp_port, default: 587, null: false
      t.string :smtp_username, default: ""
      t.string :smtp_password, default: ""
      t.string :smtp_from_email, default: "noreply@example.com"
      t.timestamps
    end

    drop_table :settings
  end

  def down
    create_table :settings do |t|
      t.string :var, null: false
      t.text :value
      t.timestamps
    end
    add_index :settings, :var, unique: true

    drop_table :app_configs
  end
end
