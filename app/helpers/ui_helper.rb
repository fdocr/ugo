module UiHelper
  # Renders an icon partial from app/views/shared/svg/_<name>.html.erb.
  #
  #   <%= icon "edit", class: "w-4 h-4" %>
  #
  # All icons accept a `class:` local. Pass any custom classes you want on
  # the rendered <svg>. The partial itself decides the default size.
  def icon(name, **options)
    render partial: "shared/svg/#{name}", locals: { class: options[:class].to_s }
  end

  # Maps a plan key (or :trial / :disabled) to a semantic badge tone.
  # Use with the ui/badge component:
  #
  #   <%= render "ui/badge", text: "Basic", tone: badge_tone_for_plan(:basic) %>
  def badge_tone_for_plan(plan)
    case plan.to_s
    when "free", "" then :neutral
    when "basic" then :primary
    when "growth" then :success
    when "dedicated" then :info
    when "trial" then :warning
    when "disabled" then :danger
    else :neutral
    end
  end
end
