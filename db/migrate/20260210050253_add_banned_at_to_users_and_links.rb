class AddBannedAtToUsersAndLinks < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :banned_at, :datetime
    add_column :links, :banned_at, :datetime
    add_index :links, :banned_at
  end
end
