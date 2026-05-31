class AddDeepLinkToAppConfigs < ActiveRecord::Migration[8.1]
  def change
    change_table :app_configs, bulk: true do |t|
      t.boolean :deep_link_enabled, default: false, null: false
      t.text :deep_link_ios_app_ids, default: "", null: false
      t.text :deep_link_android_asset_links, default: "", null: false
      t.text :deep_link_allowed_domains, default: "", null: false
      t.string :deep_link_default_destination, default: "", null: false
    end
  end
end
