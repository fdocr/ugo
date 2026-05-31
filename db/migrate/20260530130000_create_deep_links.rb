class CreateDeepLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :deep_links do |t|
      t.string :destination_url, null: false
      t.string :destination_host, null: false

      t.timestamps
    end

    add_index :deep_links, :destination_url, unique: true
    add_index :deep_links, :destination_host
  end
end
