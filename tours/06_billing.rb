# Billing screens captured for each subscription state. The tour fixtures
# preseed Subscription rows in active / past_due / cancelled / expired-trial
# states so we can screenshot the resulting UI without driving real Polar
# checkout (see docs/local-quickstart.md for the live Polar sandbox flow).
Tour.script "Billing states", modes: [ :main_app ] do
  use_session :admin

  scene "Trial banner – active trial" do
    workspace = Workspace.find_by!(name: "Acme Marketing")
    visit "/workspace/#{workspace.id}/billing"
    snapshot full_page: true, caption: "Active trial: countdown, plan comparison"
  end

  scene "Active Basic subscription" do
    workspace = Workspace.find_by!(name: "Acme Sales")
    visit "/workspace/#{workspace.id}/billing"
    snapshot full_page: true, caption: "Paying customer (Basic): cancel + manage actions"
  end
end

Tour.script "Billing edge cases", modes: [ :main_app ] do
  use_session :owner

  scene "Past-due banner" do
    workspace = Workspace.find_by!(name: "Beta Co")
    visit "/workspace/#{workspace.id}/billing"
    snapshot full_page: true, caption: "Past-due: upgrade-payment-method banner"
  end

  scene "Cancelled subscription" do
    workspace = Workspace.find_by!(name: "Quit Club")
    visit "/workspace/#{workspace.id}/billing"
    snapshot full_page: true, caption: "Cancelled: workspace paused"
  end

  scene "Expired trial – workspace blocked" do
    workspace = Workspace.find_by!(name: "Old Trial")
    visit "/workspace/#{workspace.id}/billing"
    snapshot full_page: true, caption: "Expired trial: subscription required CTA"
  end
end
