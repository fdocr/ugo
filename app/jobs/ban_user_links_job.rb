class BanUserLinksJob < ApplicationJob
  queue_as :default

  def perform(user_id:, ban:)
    user = User.find_by(id: user_id)
    return unless user

    banned_at_value = ban ? Time.current : nil
    user.owned_workspaces.each do |workspace|
      workspace.links.update_all(banned_at: banned_at_value)
    end
  end
end
