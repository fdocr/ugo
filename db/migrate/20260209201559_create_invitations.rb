class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.references :workspace, null: false, foreign_key: true
      t.string :email, null: false
      t.integer :role, null: false, default: 0
      t.string :token, null: false
      t.datetime :accepted_at
      t.datetime :expires_at, null: false
      t.references :invited_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :invitations, :token, unique: true
    add_index :invitations, [ :workspace_id, :email ], unique: true, where: "accepted_at IS NULL"
  end
end
