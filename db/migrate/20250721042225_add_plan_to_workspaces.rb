class AddPlanToWorkspaces < ActiveRecord::Migration[8.0]
  def change
    add_column :workspaces, :plan, :integer, default: 0, null: false
  end
end
