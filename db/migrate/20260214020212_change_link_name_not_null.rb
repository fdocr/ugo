class ChangeLinkNameNotNull < ActiveRecord::Migration[8.1]
  def change
    Link.where(name: nil).update_all(name: "Unnamed Link")
    change_column_null :links, :name, false
  end
end
