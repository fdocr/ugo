class Visit < ApplicationRecord
  belongs_to :visitable, polymorphic: true

  scope :for_links, -> { where(visitable_type: "Link") }
  scope :for_deep_links, -> { where(visitable_type: "DeepLink") }
  scope :since, ->(time) { where("timestamp > ?", time) }
  scope :recent, -> { since(7.days.ago) }
end
