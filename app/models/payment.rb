class Payment < ApplicationRecord
  belongs_to :subscription

  enum :status, { succeeded: 0, failed: 1 }

  validates :amount_cents, :currency, presence: true
  validates :polar_order_id, uniqueness: true, allow_nil: true

  scope :recent, -> { order(paid_at: :desc) }

  def amount_dollars
    amount_cents / 100.0
  end
end
