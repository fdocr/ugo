class Workspace < ApplicationRecord
  belongs_to :user # Original creator (for billing purposes)

  validates :name, presence: true
  validates :name, length: { maximum: 60 }
  validate :weekly_digest_requires_paid_plan

  enum :plan, { free: 0, basic: 1, dedicated: 2, growth: 3 }

  has_one :subscription, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, dependent: :destroy
  has_many :links, dependent: :destroy

  before_validation :set_dedicated_plan_if_self_hosted, on: :create
  before_validation :assign_ugo_trial_window, on: :create
  after_create :create_admin_membership
  after_create :recompute_access_blocked!
  after_update :recompute_access_blocked_if_relevant_changed

  # Attributes whose change can flip the workspace in or out of the blocked
  # state. Subscription changes are handled separately via the Subscription
  # model's after_save/after_destroy callbacks.
  ACCESS_RELEVANT_ATTRS = %w[plan trial_ends_at].freeze

  # Authorization methods
  def member?(user)
    return false unless user
    memberships.exists?(user: user)
  end

  def admin?(user)
    return false unless user
    memberships.exists?(user: user, role: :admin)
  end

  def membership_for(user)
    memberships.find_by(user: user)
  end

  def role_for(user)
    membership_for(user)&.role
  end

  def paying?
    return true if dedicated?
    return false unless subscription

    subscription.active? || subscription.past_due?
  end

  # Cardless Basic trial on the main app only; ends when the user subscribes (trial_ends_at cleared) or time runs out.
  def trial?
    return false if dedicated?
    return false if AppConfig.self_hosted?
    return false unless trial_ends_at.present?
    return false if trial_ends_at <= Time.current
    return false if paying?
    true
  end

  # Read-time check used on the link redirect hot path. Reads the denormalized
  # column populated by callbacks (Subscription, Workspace plan/trial changes)
  # and refreshed periodically by RefreshWorkspaceAccessJob. The two early
  # returns are O(1) in-memory: dedicated? is a column read and
  # AppConfig.self_hosted? is memoized at the class level.
  def ugo_access_blocked?
    return false if AppConfig.self_hosted?
    return false if dedicated?
    access_blocked_at.present?
  end

  # Recomputes the blocked state from authoritative sources (subscription,
  # trial window, plan, hosting mode) and persists it via update_columns to
  # skip callbacks/validations. Idempotent: only writes when the flag flips.
  #
  # Resets the subscription association cache first so callers invoked from
  # inside Subscription's after_save/after_destroy see the freshly persisted
  # row rather than a stale has_one target (Rails sets the inverse target
  # *after* the save callbacks return).
  def recompute_access_blocked!
    association(:subscription).reset
    blocked = compute_access_blocked
    currently_blocked = access_blocked_at.present?
    return if blocked == currently_blocked

    update_columns(access_blocked_at: blocked ? Time.current : nil)
  end

  def current_month_events
    links.joins(:visits).where("visits.timestamp >= ?", Time.current.beginning_of_month)
  end

  def link_limit_reached?
    return false if dedicated?
    return true unless paying? || trial?

    if trial? || basic?
      links.count >= 1_000
    elsif growth?
      links.count >= 3_000
    elsif free?
      links.count >= 10
    else
      false
    end
  end

  def top_links_by_visits(since:, limit: 10)
    links
      .joins(:visits)
      .where(visits: { processed_at: since.. })
      .group("links.id")
      .order("COUNT(visits.id) DESC")
      .limit(limit)
      .select("links.*, COUNT(visits.id) AS visit_count")
  end

  def event_limit_reached?
    return false if dedicated?
    return true unless paying? || trial?

    Rails.cache.fetch("workspace_event_limit_#{id}_#{updated_at.to_i}", expires_in: 30.minutes) do
      if trial? || basic?
        current_month_events.count >= 10_000
      elsif growth?
        current_month_events.count >= 50_000
      elsif free?
        current_month_events.count >= 1_000
      else
        false
      end
    end
  end

  def self.trial_duration_days
    ENV.fetch("UGO_TRIAL_DURATION_DAYS", 14).to_i.clamp(1, 365)
  end

  OPEN_BETA_ACTIVITY_WINDOW = 30.days

  def open_beta_active?
    return false unless user

    if user.last_login_at.present? && user.last_login_at >= OPEN_BETA_ACTIVITY_WINDOW.ago
      return true
    end

    links.joins(:visits).where("visits.timestamp >= ?", OPEN_BETA_ACTIVITY_WINDOW.ago).exists?
  end

  private

  def compute_access_blocked
    return false if dedicated?
    return false if AppConfig.self_hosted?
    return false if paying?
    return false if trial?
    true
  end

  def recompute_access_blocked_if_relevant_changed
    return unless saved_changes.keys.intersect?(ACCESS_RELEVANT_ATTRS)
    recompute_access_blocked!
  end

  def create_admin_membership
    memberships.create!(user: user, role: :admin)
  end

  def weekly_digest_requires_paid_plan
    if weekly_digest? && free? && !trial?
      errors.add(:weekly_digest, "is only available on paid plans")
    end
  end

  def set_dedicated_plan_if_self_hosted
    self.plan = :dedicated if AppConfig.self_hosted?
  end

  def assign_ugo_trial_window
    return if dedicated?
    return if AppConfig.self_hosted?
    return if trial_ends_at.present?
    return unless free?

    self.trial_ends_at = self.class.trial_duration_days.days.from_now
  end
end
