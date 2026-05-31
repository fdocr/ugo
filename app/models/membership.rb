class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :workspace

  enum :role, { member: 0, admin: 1 }

  validates :user_id, uniqueness: { scope: :workspace_id, message: "is already a member of this workspace" }
  validates :role, presence: true

  scope :admins, -> { where(role: :admin) }
end
