class ChangeDefaultAmountCentsOnSubscriptions < ActiveRecord::Migration[8.1]
  def change
    change_column_default :subscriptions, :amount_cents, from: 1499, to: 900
  end
end
