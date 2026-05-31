class AddApiTokenToWorkspace < ActiveRecord::Migration[8.0]
  def change
    add_column :workspaces, :api_token, :string
    add_index :workspaces, :api_token
  end
end
