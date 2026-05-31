class ProcessVisitsJob < ApplicationJob
  queue_as :default

  def perform
    unless Visit.exists?(processed_at: nil)
      Rails.logger.info "No visits to process"
      return
    end

    mmdb_path = "./GeoLite2-City.mmdb"
    unless File.exist?(mmdb_path)
      Rails.logger.warn "GeoLite2-City.mmdb not found, skipping visit processing until the database is available"
      return
    end

    mmdb = MaxMindDB.new(mmdb_path)
    mmdb.local_ip_alias = "170.203.222.142"
    total_processed = 0

    Visit.includes(:visitable)
      .where("timestamp < ?", Time.current)
      .where(processed_at: nil)
      .order(timestamp: :desc)
      .find_each(batch_size: 50) do |visit|
      claimed_at = Time.current
      next unless Visit.where(id: visit.id, processed_at: nil).update_all(processed_at: claimed_at) == 1

      visit.reload
      next unless process_visit(visit, mmdb, claimed_at)

      total_processed += 1
    end

    Rails.logger.info "ProcessVisitsJob processed #{total_processed} visits"
  end

  private

  # Each visitable (Link, DeepLink, ...) decides whether its visit should be
  # discarded and which cache namespace to bust, so the job stays type-agnostic.
  def process_visit(visit, mmdb, claimed_at)
    visitable = visit.visitable

    # Visitable deleted between claim and processing: drop the orphan.
    unless visitable
      visit.destroy
      return true
    end

    if (reason = visitable.visit_discard_reason)
      Rails.logger.info "Discarding visit #{visit.id}: #{reason}"
      visit.destroy
      return true
    end

    enrich_visit(visit, mmdb, claimed_at, cache_key_prefix: visitable.analytics_cache_prefix)
  end

  def enrich_visit(visit, mmdb, claimed_at, cache_key_prefix:)
    detector = CrawlerDetect.new(visit.user_agent)
    if detector.is_crawler?
      Rails.logger.info "Destroying visit #{visit.id} because it's a crawler (#{detector.crawler_name})"
      visit.destroy
      return true
    end

    begin
      processed_data = geo_and_device_data(visit, mmdb)
      %w[day week month].each do |range|
        Rails.cache.delete("#{cache_key_prefix}_#{range}")
      end
      visit.update_columns(processed_data)
      true
    rescue StandardError => e
      Visit.where(id: visit.id, processed_at: claimed_at).update_all(processed_at: nil)
      Rails.logger.error "Failed to process visit #{visit.id}: #{e.message}"
      false
    end
  end

  def geo_and_device_data(visit, mmdb)
    processed_data = {}
    result = mmdb.lookup(visit.ip_address)
    if result.found?
      processed_data[:country_code] = result.country.iso_code
      processed_data[:country] = result.country.name
      processed_data[:subdivision] = result.subdivisions.most_specific.name
      processed_data[:city] = result.city.name
      processed_data[:latitude] = result.location.latitude
      processed_data[:longitude] = result.location.longitude
      processed_data[:accuracy_radius] = result.location.accuracy_radius
    end

    client = DeviceDetector.new(visit.user_agent)
    if client.known?
      processed_data[:device_type] = client.device_type
      processed_data[:browser_name] = client.name
      processed_data[:os_name] = client.os_name
    end

    processed_data[:ip_address] = nil
    processed_data[:user_agent] = nil
    processed_data
  end
end
