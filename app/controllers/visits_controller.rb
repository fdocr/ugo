class VisitsController < ApplicationController
  include VisitsHelper
  include EnforceUgoWorkspaceAccess
  MAX_CHART_ITEMS = 20
  VALID_TIME_RANGES = [ "day", "week", "month" ]

  before_action :load_workspace
  before_action :authorize_workspace_member!
  before_action :ensure_ugo_workspace_active!
  before_action :load_link

  def index
    @time_range = VALID_TIME_RANGES.include?(params[:time_range]) ? params[:time_range] : "week"
    @chart_data = cached_chart_data
    calculate_summary_stats
  end

  private

  def cache_key
    "#{@link.id}_visits_charts_#{@time_range}"
  end

  def cached_chart_data
    Rails.cache.fetch(cache_key, expires_in: 60.minutes) do
      scope = @link.visits.where.not(processed_at: nil)
      scope = apply_time_filter(scope)
      prepare_all_chart_data(scope.order(timestamp: :desc))
    end
  end

  def apply_time_filter(scope)
    case @time_range
    when "day"
      scope.where("timestamp > ?", 1.day.ago)
    when "month"
      scope.where("timestamp > ?", 1.month.ago)
    else # default to week
      scope.where("timestamp > ?", 1.week.ago)
    end
  end

  def prepare_all_chart_data(scope)
    {
      visitors: prepare_visitors_data(scope),
      devices: {
        device_type: prepare_device_data(scope, :device_type, "Unknown Device"),
        browser_name: prepare_device_data(scope, :browser_name, "Unknown Browser"),
        os_name: prepare_device_data(scope, :os_name, "Unknown OS")
      },
      geo: {
        country: prepare_geo_data(scope, :country, "Unknown Country"),
        subdivision: prepare_geo_data(scope, :subdivision, "Unknown Region"),
        city: prepare_geo_data(scope, :city, "Unknown City")
      },
      map: prepare_map_data(scope)
    }
  end

  def prepare_visitors_data(scope)
    # Group visits by day and count them
    grouped_visits = scope.group_by { |visit| visit.timestamp.to_date }

    # Get date range for the chart
    end_date = Date.current
    start_date = case @time_range
    when "day"
      1.day.ago.to_date
    when "month"
      1.month.ago.to_date
    else # default to week
      1.week.ago.to_date
    end

    # Create array of dates and counts
    dates = []
    counts = []

    (start_date..end_date).each do |date|
      dates << date.strftime("%b %d")
      counts << (grouped_visits[date]&.count || 0)
    end

    { labels: dates, data: counts }
  end

  def prepare_device_data(scope, field, unknown_label)
    # Group visits by the specified field and sort by count descending
    counts = scope.where.not(field => nil).group(field).count
    sorted_counts = counts.sort_by { |_, count| -count }

    categories = []
    data = []

    # Take top MAX_CHART_ITEMS and aggregate the rest as "Others"
    top_items = sorted_counts.first(MAX_CHART_ITEMS)
    others = sorted_counts.drop(MAX_CHART_ITEMS)

    top_items.each do |name, count|
      categories << name&.titleize || unknown_label
      data << count
    end

    if others.any?
      others_count = others.sum { |_, count| count }
      categories << "Others"
      data << others_count
    end

    { labels: categories, data: data }
  end

  def prepare_geo_data(scope, field, unknown_label)
    # Group visits by the specified field and sort by count descending
    counts = scope.where.not(field => nil).group(field).count
    sorted_counts = counts.sort_by { |_, count| -count }

    categories = []
    data = []

    # Take top MAX_CHART_ITEMS and aggregate the rest as "Others"
    top_items = sorted_counts.first(MAX_CHART_ITEMS)
    others = sorted_counts.drop(MAX_CHART_ITEMS)

    top_items.each do |name, count|
      categories << name || unknown_label
      data << count
    end

    if others.any?
      others_count = others.sum { |_, count| count }
      categories << "Others"
      data << others_count
    end

    { labels: categories, data: data }
  end

  def prepare_map_data(scope)
    # Group visits by country_code for DataMaps (uses ISO 3-letter codes)
    country_data = scope.where.not(country_code: nil)
                        .group(:country_code, :country)
                        .count

    # DataMaps uses ISO 3166-1 alpha-3 codes, but GeoIP stores alpha-2
    # Convert 2-letter to 3-letter codes
    map_data = {}
    country_names = {}
    country_data.each do |(code, name), count|
      next if code.blank?
      alpha3 = iso_alpha2_to_alpha3[code.upcase]
      next unless alpha3
      map_data[alpha3] = (map_data[alpha3] || 0) + count
      country_names[alpha3] = name
    end

    {
      data: map_data,
      names: country_names,
      max: map_data.values.max || 0
    }
  end

  def calculate_summary_stats
    scope = @link.visits.where.not(processed_at: nil)
    scope = apply_time_filter(scope)

    @visits_count = scope.count
    @unique_visitors_count = scope.where.not(visitor_hash: nil).distinct.count(:visitor_hash)
    @unique_countries_count = scope.where.not(country: nil).distinct.count(:country)
  end

  def load_workspace
    @workspace = Current.user.workspaces.find_by(id: params[:workspace_id])
    redirect_to dashboard_path, notice: "Workspace not found" if @workspace.nil?
  end

  def load_link
    @link = @workspace.links.find_by(slug: params[:link_id])
    redirect_to dashboard_path, notice: "Link not found" if @link.nil?
  end
end
