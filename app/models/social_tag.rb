class SocialTag < ApplicationRecord
  REFRESH_COOLDOWN = 5.minutes

  belongs_to :link
end
