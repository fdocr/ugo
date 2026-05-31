require "test_helper"

class WorkspaceHelperTest < ActionView::TestCase
  test "plan_color_classes returns neutral tone for free plan" do
    classes = plan_color_classes("free")
    assert_includes classes, "ui-badge-sm"
    assert_includes classes, "ui-badge-neutral"
  end

  test "plan_color_classes returns primary tone for basic plan" do
    classes = plan_color_classes("basic")
    assert_includes classes, "ui-badge-primary"
  end

  test "plan_color_classes returns success tone for growth plan" do
    classes = plan_color_classes("growth")
    assert_includes classes, "ui-badge-success"
  end

  test "plan_color_classes returns info tone for dedicated plan" do
    classes = plan_color_classes("dedicated")
    assert_includes classes, "ui-badge-info"
  end

  test "plan_color_classes returns warning tone for trial key" do
    classes = plan_color_classes("trial")
    assert_includes classes, "ui-badge-warning"
  end

  test "plan_color_classes returns danger tone for disabled key" do
    classes = plan_color_classes("disabled")
    assert_includes classes, "ui-badge-danger"
  end

  test "plan_color_classes falls back to neutral for unknown plan" do
    classes = plan_color_classes("unknown")
    assert_includes classes, "ui-badge-neutral"
  end

  test "plan_badge generates correct HTML for basic workspace" do
    workspace = Workspace.new(plan: "basic")
    def workspace.ugo_access_blocked?; false; end
    def workspace.trial?; false; end

    badge_html = plan_badge(workspace)

    assert_includes badge_html, "<span"
    assert_includes badge_html, "ui-badge-primary"
    assert_includes badge_html, "Basic Plan"
  end

  test "plan_badge shows trial label when in trial" do
    workspace = Workspace.new(plan: "free", trial_ends_at: 1.day.from_now)
    def workspace.ugo_access_blocked?; false; end
    def workspace.dedicated?; false; end
    def workspace.subscription; nil; end

    badge_html = plan_badge(workspace)

    assert_includes badge_html, "Trial · Basic"
    assert_includes badge_html, "ui-badge-warning"
  end

  test "plan_badge shows subscription required when disabled" do
    workspace = Workspace.new(plan: "free")
    def workspace.ugo_access_blocked?; true; end

    badge_html = plan_badge(workspace)

    assert_includes badge_html, "Subscription required"
    assert_includes badge_html, "ui-badge-danger"
  end

  test "plan_badge generates correct HTML for growth workspace" do
    workspace = Workspace.new(plan: "growth")
    def workspace.ugo_access_blocked?; false; end
    def workspace.trial?; false; end

    badge_html = plan_badge(workspace)

    assert_includes badge_html, "<span"
    assert_includes badge_html, "ui-badge-success"
    assert_includes badge_html, "Growth Plan"
  end

  test "plan_badge generates correct HTML for dedicated workspace" do
    workspace = Workspace.new(plan: "dedicated")
    def workspace.ugo_access_blocked?; false; end
    def workspace.trial?; false; end

    badge_html = plan_badge(workspace)

    assert_includes badge_html, "<span"
    assert_includes badge_html, "ui-badge-info"
    assert_includes badge_html, "Dedicated Plan"
  end
end
