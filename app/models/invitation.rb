class Invitation < ApplicationRecord
  belongs_to :workspace
  belongs_to :invited_by, class_name: "User"

  enum :role, { member: 0, admin: 1 }

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validate :no_duplicate_pending_invitation, on: :create

  normalizes :email, with: ->(e) { e.strip.downcase }

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where(accepted_at: nil).where("expires_at <= ?", Time.current) }

  def pending?
    accepted_at.nil? && expires_at > Time.current
  end

  def expired?
    accepted_at.nil? && expires_at <= Time.current
  end

  def accepted?
    accepted_at.present?
  end

  def accept!(user)
    transaction do
      update!(accepted_at: Time.current)
      workspace.memberships.create!(user: user, role: role)
    end
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiration
    self.expires_at ||= 7.days.from_now
  end

  def no_duplicate_pending_invitation
    return unless workspace && email

    existing = workspace.invitations.pending.where(email: email.strip.downcase).exists?
    errors.add(:email, "has already been invited to this workspace") if existing
  end
end
