# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_30_130100) do
  create_table "app_configs", force: :cascade do |t|
    t.string "admin_api_key", default: "admin-secret-key"
    t.text "admin_scripts", default: "", null: false
    t.string "app_domain", default: "", null: false
    t.string "app_name", default: "ugo", null: false
    t.datetime "created_at", null: false
    t.text "deep_link_allowed_domains", default: "", null: false
    t.text "deep_link_android_asset_links", default: "", null: false
    t.string "deep_link_default_destination", default: "", null: false
    t.boolean "deep_link_enabled", default: false, null: false
    t.text "deep_link_ios_app_ids", default: "", null: false
    t.string "honeybadger_api_key", default: ""
    t.string "polar_access_token", default: ""
    t.string "polar_basic_product_id", default: ""
    t.string "polar_growth_product_id", default: ""
    t.boolean "polar_sandbox", default: false
    t.string "polar_webhook_secret", default: ""
    t.string "setup_code", default: ""
    t.boolean "setup_completed", default: false, null: false
    t.string "smtp_address", default: ""
    t.string "smtp_from_email", default: "noreply@example.com"
    t.string "smtp_password", default: ""
    t.integer "smtp_port", default: 587, null: false
    t.string "smtp_username", default: ""
    t.datetime "updated_at", null: false
  end

  create_table "deep_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "destination_host", null: false
    t.string "destination_url", null: false
    t.datetime "updated_at", null: false
    t.index ["destination_host"], name: "index_deep_links_on_destination_host"
    t.index ["destination_url"], name: "index_deep_links_on_destination_url", unique: true
  end

  create_table "flipper_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.integer "invited_by_id", null: false
    t.integer "role", default: 0, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.integer "workspace_id", null: false
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
    t.index ["workspace_id", "email"], name: "index_invitations_on_workspace_id_and_email", unique: true, where: "accepted_at IS NULL"
    t.index ["workspace_id"], name: "index_invitations_on_workspace_id"
  end

  create_table "links", force: :cascade do |t|
    t.datetime "banned_at"
    t.string "comments"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "qr_code"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.integer "workspace_id", null: false
    t.index ["banned_at"], name: "index_links_on_banned_at"
    t.index ["slug"], name: "index_links_on_slug", unique: true
    t.index ["workspace_id"], name: "index_links_on_workspace_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "workspace_id", null: false
    t.index ["user_id", "workspace_id"], name: "index_memberships_on_user_id_and_workspace_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.index ["workspace_id"], name: "index_memberships_on_workspace_id"
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.datetime "paid_at"
    t.string "polar_order_id"
    t.integer "status", default: 0, null: false
    t.integer "subscription_id", null: false
    t.datetime "updated_at", null: false
    t.index ["polar_order_id"], name: "index_payments_on_polar_order_id", unique: true
    t.index ["subscription_id"], name: "index_payments_on_subscription_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "last_active_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "social_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "image_url"
    t.integer "link_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["link_id"], name: "index_social_tags_on_link_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.integer "amount_cents", default: 900, null: false
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.datetime "current_period_end"
    t.datetime "current_period_start"
    t.string "customer_email"
    t.string "polar_customer_id"
    t.string "polar_product_id"
    t.string "polar_subscription_id"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "workspace_id", null: false
    t.index ["polar_subscription_id"], name: "index_subscriptions_on_polar_subscription_id", unique: true
    t.index ["workspace_id"], name: "index_subscriptions_on_workspace_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "banned_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "last_login_at"
    t.string "login_token"
    t.datetime "login_token_expires_at"
    t.string "password_digest"
    t.boolean "site_admin", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["login_token"], name: "index_users_on_login_token"
  end

  create_table "visits", force: :cascade do |t|
    t.integer "accuracy_radius"
    t.string "browser_name"
    t.string "city"
    t.string "country"
    t.string "country_code"
    t.string "device_type"
    t.string "ip_address"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "os_name"
    t.datetime "processed_at"
    t.string "referer"
    t.string "subdivision"
    t.datetime "timestamp", null: false
    t.string "user_agent"
    t.integer "visitable_id", null: false
    t.string "visitable_type", null: false
    t.string "visitor_hash"
    t.index ["processed_at"], name: "index_visits_on_processed_at"
    t.index ["timestamp"], name: "index_visits_on_timestamp"
    t.index ["visitable_type", "visitable_id"], name: "index_visits_on_visitable_type_and_visitable_id"
    t.index ["visitor_hash"], name: "index_visits_on_visitor_hash"
  end

  create_table "workspaces", force: :cascade do |t|
    t.datetime "access_blocked_at"
    t.string "api_token"
    t.datetime "created_at", null: false
    t.string "domain"
    t.boolean "monthly_digest", default: false, null: false
    t.string "name", default: "Default", null: false
    t.integer "plan", default: 0, null: false
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.boolean "weekly_digest", default: false, null: false
    t.index ["access_blocked_at"], name: "index_workspaces_on_access_blocked_at"
    t.index ["api_token"], name: "index_workspaces_on_api_token"
    t.index ["domain"], name: "index_workspaces_on_domain", unique: true
    t.index ["name"], name: "index_workspaces_on_name"
    t.index ["trial_ends_at"], name: "index_workspaces_on_trial_ends_at"
    t.index ["user_id"], name: "index_workspaces_on_user_id"
  end

  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "invitations", "workspaces"
  add_foreign_key "links", "workspaces"
  add_foreign_key "memberships", "users"
  add_foreign_key "memberships", "workspaces"
  add_foreign_key "payments", "subscriptions"
  add_foreign_key "sessions", "users"
  add_foreign_key "social_tags", "links"
  add_foreign_key "subscriptions", "workspaces"
  add_foreign_key "workspaces", "users"
end
