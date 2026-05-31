# The public-facing redirect endpoint (`links#link`) — both the normal
# countdown view and the new 402 link-unavailable page for blocked
# workspaces. No login required.
Tour.script "Public redirect", modes: [ :main_app ] do
  scene "Active link – redirect splash" do
    # links#link redirects via window.location.href on page load. Disable JS
    # so we can actually see the splash page that exists for the rare case
    # where the redirect is slow.
    disable_javascript
    visit "/spring-2026"
    snapshot caption: "links#link splash (only visible if the JS redirect lags)", pause: 1
    enable_javascript
  end

  scene "Blocked workspace – link unavailable (402)" do
    blocked = Workspace.find_by!(name: "Old Trial")
    Link.find_or_create_by!(workspace: blocked, slug: "blocked-demo") do |l|
      l.name = "Blocked demo"
      l.url = "https://example.com/blocked"
    end
    visit "/blocked-demo"
    snapshot caption: "402 Payment Required when access_blocked_at is set", pause: 1
  end

  scene "Unknown slug – flash redirect" do
    visit "/this-slug-does-not-exist"
    snapshot caption: "Unknown slug: redirected home with a flash message"
  end
end
