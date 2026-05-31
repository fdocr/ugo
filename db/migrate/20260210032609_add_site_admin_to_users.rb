class AddSiteAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :site_admin, :boolean, default: false, null: false
  end
end
