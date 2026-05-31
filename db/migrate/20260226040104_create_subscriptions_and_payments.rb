class CreateSubscriptionsAndPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :workspace, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, default: 0, null: false
      t.string :polar_subscription_id, index: { unique: true }
      t.string :polar_customer_id
      t.string :polar_product_id
      t.string :customer_email
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.integer :amount_cents, default: 1499, null: false
      t.string :currency, default: "USD", null: false
      t.datetime :cancelled_at

      t.timestamps
    end

    create_table :payments do |t|
      t.references :subscription, null: false, foreign_key: true
      t.integer :amount_cents, null: false
      t.string :currency, null: false
      t.integer :status, default: 0, null: false
      t.string :polar_order_id, index: { unique: true }
      t.datetime :paid_at

      t.timestamps
    end
  end
end
