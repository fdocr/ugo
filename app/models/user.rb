class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :member_workspaces, through: :memberships, source: :workspace
  has_many :invitations_sent, class_name: "Invitation", foreign_key: :invited_by_id, dependent: :nullify

  # Workspaces this user originally created (for billing)
  has_many :owned_workspaces, class_name: "Workspace", dependent: :destroy
  has_many :links, through: :owned_workspaces

  normalizes :email, with: ->(e) { e.strip.downcase }

  validates :email, presence: true, uniqueness: true

  # Alias for backward compatibility during transition
  alias_method :workspaces, :member_workspaces

  def logged_in!
    self.last_login_at = Time.current
    self.save!
  end

  def banned?
    banned_at.present?
  end

  def ban!
    update!(banned_at: Time.current)
    sessions.destroy_all
    BanUserLinksJob.perform_later(user_id: id, ban: true)
  end

  def unban!
    update!(banned_at: nil)
    BanUserLinksJob.perform_later(user_id: id, ban: false)
  end

  # Find pending invitations for this user's email
  def pending_invitations
    Invitation.pending.where(email: email)
  end
end
