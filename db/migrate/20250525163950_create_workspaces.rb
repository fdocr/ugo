class CreateWorkspaces < ActiveRecord::Migration[8.0]
  def change
    create_table :workspaces do |t|
      t.string :slug, null: false, index: { unique: true }

      t.belongs_to :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
