class Subscription < ApplicationRecord
  belongs_to :workspace
  has_many :payments, dependent: :destroy

  enum :status, { active: 0, past_due: 1, cancelled: 2 }

  validates :workspace_id, uniqueness: true
  validates :polar_subscription_id, uniqueness: true, allow_nil: true
  validates :amount_cents, :currency, presence: true

  # Keep the workspace's denormalized access_blocked_at flag in sync whenever
  # the subscription changes — the link redirect hot path reads only that column.
  after_save :recompute_workspace_access
  after_destroy :recompute_workspace_access

  def amount_dollars
    amount_cents / 100.0
  end

  def next_payment_date
    current_period_end&.to_date
  end

  def pending_cancellation?
    cancelled_at.present? && active?
  end

  private

  def recompute_workspace_access
    workspace&.recompute_access_blocked!
  end
end
