class RemoveRoleFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :role, :integer
  end
end
