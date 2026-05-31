class CreateLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :links do |t|
      t.string :name
      t.string :slug, null: false, index: { unique: true }
      t.string :url
      t.string :comments

      t.belongs_to :workspace, null: false, foreign_key: true

      t.timestamps
    end
  end
end
