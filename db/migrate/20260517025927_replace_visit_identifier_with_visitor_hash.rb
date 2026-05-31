class ReplaceVisitIdentifierWithVisitorHash < ActiveRecord::Migration[8.0]
  def change
    remove_index :visits, :identifier
    remove_column :visits, :identifier, :string

    add_column :visits, :visitor_hash, :string
    add_index :visits, :visitor_hash
  end
end
