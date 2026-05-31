module WorkspaceHelper
  include UiHelper

  # Renders the workspace plan badge using the ui/badge component so the
  # design system (tones, radius, ring) stays in one place.
  def plan_badge(workspace)
    label, key = plan_badge_parts(workspace)
    render "ui/badge", text: label, tone: badge_tone_for_plan(key)
  end

  def plan_badge_parts(workspace)
    if workspace.ugo_access_blocked?
      [ "Subscription required", "disabled" ]
    elsif workspace.trial?
      [ "Trial · Basic", "trial" ]
    else
      [ "#{workspace.plan.titleize} Plan", workspace.plan ]
    end
  end

  # Kept for the admin tables that render a small plan-tag chip inline.
  # Routes to the same tone vocabulary used by ui/badge.
  def plan_color_classes(plan)
    tone = badge_tone_for_plan(plan)
    "ui-badge-sm ui-badge-#{tone}"
  end
end
