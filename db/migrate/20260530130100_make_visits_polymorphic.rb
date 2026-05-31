class MakeVisitsPolymorphic < ActiveRecord::Migration[8.1]
  def up
    add_column :visits, :visitable_type, :string
    add_column :visits, :visitable_id, :integer

    execute <<~SQL.squish
      UPDATE visits
      SET visitable_type = 'Link', visitable_id = link_id
    SQL

    change_column_null :visits, :visitable_type, false
    change_column_null :visits, :visitable_id, false

    remove_index :visits, :link_id
    remove_column :visits, :link_id

    add_index :visits, [ :visitable_type, :visitable_id ]
  end

  def down
    add_column :visits, :link_id, :integer
    add_index :visits, :link_id

    execute <<~SQL.squish
      UPDATE visits
      SET link_id = visitable_id
      WHERE visitable_type = 'Link'
    SQL

    change_column_null :visits, :link_id, false

    remove_index :visits, column: [ :visitable_type, :visitable_id ]
    remove_column :visits, :visitable_type
    remove_column :visits, :visitable_id
  end
end
