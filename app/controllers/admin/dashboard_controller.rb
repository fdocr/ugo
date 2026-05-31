# frozen_string_literal: true

class Admin::DashboardController < AdminController
  include Pagy::Method

  def index
    @stats = Admin::DashboardStats.fetch
    @page_title = "Admin Dashboard"
    @back_url = dashboard_path
  end

  def workspaces
    @search = params[:search]
    @sort = params[:sort] || "recent"
    @pagy, @workspaces = pagy(filtered_workspaces)
  end

  def links
    @sort = params[:sort] || "recent"
    @search = params[:search]
    @pagy, @links = pagy(filtered_links)
  end

  def deep_links
    @sort = params[:sort] || "visits"
    @search = params[:search]
    @pagy, @deep_links = pagy(filtered_deep_links)
  end

  def settings
    @config = AppConfig.shared
    @page_title = "Site Settings"
    @back_url = admin_root_path
  end

  def update_settings
    attrs = settings_params.to_h.symbolize_keys
    attrs[:smtp_port] = attrs[:smtp_port].to_i if attrs.key?(:smtp_port)
    attrs.delete(:smtp_password) if params[:smtp_password].blank?
    # Unchecked checkboxes are simply absent from params, so coerce explicitly.
    attrs[:deep_link_enabled] = params[:deep_link_enabled] == "1"
    assign_clearable_secret(attrs, :honeybadger_api_key)
    assign_polar_settings(attrs) if AppConfig.main_app?

    AppConfig.shared.update!(attrs)
    AppConfig.configure_smtp! if Rails.env.production?
    AppConfig.configure_polar! if Rails.env.production? && AppConfig.main_app?
    redirect_to admin_settings_path, notice: "Settings updated successfully."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_settings_path, alert: "Failed to update settings: #{e.message}"
  end

  def new_user
    unless self_hosted?
      redirect_to admin_root_path, alert: "User creation is only available on self-hosted installations."
      return
    end

    admin_workspace = Current.user.workspaces.first
    redirect_to workspace_path(admin_workspace), notice: "To add a user invite them to your workspace with an assigned role."
  end

  def create_user
    unless self_hosted?
      redirect_to admin_root_path, alert: "User creation is only available on self-hosted installations."
      return
    end

    password = SecureRandom.hex(8)
    user = User.new(
      email: params[:email],
      password: password,
      password_confirmation: password
    )

    ActiveRecord::Base.transaction do
      user.save!
      admin_workspace = Current.user.workspaces.first
      admin_workspace.memberships.create!(user: user, role: :member)
    end

    AdminMailer.user_created(user, password).deliver_later
    redirect_to admin_root_path, notice: "User #{user.email} created. Login credentials sent via email."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_new_user_path, alert: "Failed to create user: #{e.message}"
  end

  def ban_user
    @user = User.find(params[:id])
    @user.ban!
    redirect_to admin_root_path, notice: "#{@user.email} has been banned. All sessions terminated and links are being disabled."
  end

  def unban_user
    @user = User.find(params[:id])
    @user.unban!
    redirect_to admin_root_path, notice: "#{@user.email} has been unbanned. Links are being re-enabled."
  end

  private

  # Plain text settings. Booleans (checkboxes) and clearable secrets are handled
  # separately because absent params carry meaning for them.
  def settings_params
    params.permit(
      :app_name, :app_domain,
      :smtp_address, :smtp_port, :smtp_username, :smtp_from_email, :smtp_password,
      :admin_scripts,
      :deep_link_ios_app_ids, :deep_link_android_asset_links,
      :deep_link_allowed_domains, :deep_link_default_destination
    )
  end

  # A secret paired with a "clear_<key>" checkbox: blank it when cleared, replace
  # it when a new value is given, and otherwise leave the stored value untouched.
  def assign_clearable_secret(attrs, key)
    if params[:"clear_#{key}"] == "1"
      attrs[key] = ""
    elsif params[key].present?
      attrs[key] = params[key]
    end
  end

  def assign_polar_settings(attrs)
    attrs[:polar_basic_product_id] = params[:polar_basic_product_id].to_s
    attrs[:polar_growth_product_id] = params[:polar_growth_product_id].to_s
    attrs[:polar_sandbox] = params[:polar_sandbox] == "1"
    assign_clearable_secret(attrs, :polar_access_token)
    assign_clearable_secret(attrs, :polar_webhook_secret)
  end

  def filtered_workspaces
    scope = sorted_workspaces
    if @search.present?
      scope = scope.joins(:user).where("LOWER(users.email) LIKE ?", "%#{@search.downcase}%")
    end
    scope
  end

  def sorted_workspaces
    case @sort
    when "links"
      Workspace.includes(:user, :links)
               .left_joins(:links)
               .group("workspaces.id")
               .order(Arel.sql("COUNT(links.id) DESC"))
    else
      Workspace.includes(:user, :links).order(created_at: :desc)
    end
  end

  def filtered_links
    scope = sorted_links
    if @search.present?
      search_term = "%#{@search.downcase}%"
      scope = scope.where(
        "LOWER(links.url) LIKE ? OR LOWER(links.name) LIKE ? OR LOWER(links.slug) LIKE ?",
        search_term, search_term, search_term
      )
    end
    scope
  end

  def sorted_links
    case @sort
    when "visits"
      links_by_visits
    else
      Link.includes(:workspace).order(created_at: :desc)
    end
  end

  def links_by_visits
    # Use a subquery to count visits and order by that count
    Link.includes(:workspace)
        .left_joins(:visits)
        .where("visits.timestamp > ? OR visits.id IS NULL", 7.days.ago)
        .group("links.id")
        .order(Arel.sql("COUNT(visits.id) DESC"))
  end

  def filtered_deep_links
    scope = sorted_deep_links
    if @search.present?
      term = "%#{@search.downcase}%"
      scope = scope.where(
        "LOWER(deep_links.destination_url) LIKE ? OR LOWER(deep_links.destination_host) LIKE ?",
        term, term
      )
    end
    scope
  end

  def sorted_deep_links
    # Count recent bounces in the same grouped query so the view can read
    # recent_visits_count per row instead of firing a COUNT per rendered row.
    scope = DeepLink.left_joins(:visits)
                    .where("visits.timestamp > ? OR visits.id IS NULL", 7.days.ago)
                    .group("deep_links.id")
                    .select("deep_links.*, COUNT(visits.id) AS recent_visits_count")

    case @sort
    when "recent"
      scope.order("deep_links.created_at DESC")
    else
      scope.order(Arel.sql("COUNT(visits.id) DESC"))
    end
  end
end
