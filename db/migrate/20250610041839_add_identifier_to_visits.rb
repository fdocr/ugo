class AddIdentifierToVisits < ActiveRecord::Migration[8.0]
  def change
    add_column :visits, :identifier, :string
    add_index :visits, :identifier
  end
end
