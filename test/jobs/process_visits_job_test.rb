require "test_helper"

class ProcessVisitsJobTest < ActiveJob::TestCase
  MMDB_PATH = "./GeoLite2-City.mmdb"

  setup do
    @link = links(:one)
    Visit.where(processed_at: nil).update_all(processed_at: Time.current)
  end

  test "atomically claims each visit so only one worker can process it" do
    visit = create_unprocessed_visit!

    assert_equal 1, Visit.where(id: visit.id, processed_at: nil).update_all(processed_at: Time.current)
    assert_equal 0, Visit.where(id: visit.id, processed_at: nil).update_all(processed_at: Time.current)
  end

  test "processes an unprocessed visit and clears raw PII" do
    visit = create_unprocessed_visit!
    lookup_calls = 0
    fake_mmdb = build_fake_mmdb { lookup_calls += 1 }

    with_mmdb_available(fake_mmdb) do
      ProcessVisitsJob.perform_now
    end

    visit.reload
    assert_not_nil visit.processed_at
    assert_nil visit.ip_address
    assert_nil visit.user_agent
    assert_equal "US", visit.country_code
    assert_equal 1, lookup_calls
    assert_empty Visit.where(processed_at: nil, id: visit.id)
  end

  test "concurrent jobs enrich each visit exactly once" do
    visits = 3.times.map { create_unprocessed_visit! }
    lookup_calls = []
    lookup_mutex = Mutex.new
    fake_mmdb = build_fake_mmdb do
      lookup_mutex.synchronize { lookup_calls << true }
    end

    with_mmdb_available(fake_mmdb) do
      ready = Concurrent::CountDownLatch.new(2)
      start = Concurrent::CountDownLatch.new(1)

      threads = 2.times.map do
        Thread.new do
          ready.count_down
          start.wait
          ProcessVisitsJob.perform_now
        end
      end

      ready.wait(2)
      start.count_down
      threads.each(&:join)
    end

    visits.each do |visit|
      visit.reload
      assert_not_nil visit.processed_at, "visit #{visit.id} should be processed"
      assert_nil visit.ip_address
    end

    assert_equal visits.size, lookup_calls.size
    assert_empty Visit.where(id: visits.map(&:id), processed_at: nil)
  end

  test "processes a deep link visit and busts its analytics cache" do
    deep_link = DeepLink.create!(destination_url: "https://example.com/app", destination_host: "example.com")
    visit = create_unprocessed_visit!(visitable: deep_link)
    Rails.cache.write("deep_link_#{deep_link.id}_visits_charts_week", "stale")

    with_mmdb_available(build_fake_mmdb { }) do
      ProcessVisitsJob.perform_now
    end

    visit.reload
    assert_not_nil visit.processed_at
    assert_nil visit.ip_address
    assert_nil Rails.cache.read("deep_link_#{deep_link.id}_visits_charts_week")
  end

  test "discards a link visit whose workspace can no longer record events" do
    setup_app_config_as_main_app!
    # Free, non-paying, non-trial workspace → visit_discard_reason is set, so the
    # job should drop the visit instead of enriching it.
    @link.workspace.update!(plan: :free, trial_ends_at: nil)
    visit = create_unprocessed_visit!

    with_mmdb_available(build_fake_mmdb { }) do
      assert_difference "Visit.count", -1 do
        ProcessVisitsJob.perform_now
      end
    end

    assert_nil Visit.find_by(id: visit.id)
  end

  test "releases the claim when enrichment fails so a later job can retry" do
    visit = create_unprocessed_visit!
    failing_mmdb = Object.new
    failing_mmdb.define_singleton_method(:local_ip_alias=) { |_| }
    failing_mmdb.define_singleton_method(:lookup) { |_| raise "GeoIP lookup failed" }

    with_mmdb_available(failing_mmdb) do
      ProcessVisitsJob.perform_now
    end

    visit.reload
    assert_nil visit.processed_at
    assert_equal "8.8.8.8", visit.ip_address
  end

  test "returns early when there are no unprocessed visits" do
    Visit.where(processed_at: nil).update_all(processed_at: Time.current)

    lookup_calls = 0
    fake_mmdb = build_fake_mmdb { lookup_calls += 1 }

    with_mmdb_available(fake_mmdb) do
      ProcessVisitsJob.perform_now
    end

    assert_equal 0, lookup_calls
  end

  private

  def create_unprocessed_visit!(visitable: @link)
    Visit.create!(
      visitable: visitable,
      ip_address: "8.8.8.8",
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      referer: nil,
      timestamp: 1.hour.ago,
      visitor_hash: SecureRandom.hex(12)
    )
  end

  def build_fake_mmdb(&on_lookup)
    country = Struct.new(:iso_code, :name).new("US", "United States")
    subdivisions = Struct.new(:most_specific).new(Struct.new(:name).new("California"))
    city = Struct.new(:name).new("Mountain View")
    location = Struct.new(:latitude, :longitude, :accuracy_radius).new(37.386, -122.0838, 100)
    result = Struct.new(:found?, :country, :subdivisions, :city, :location).new(true, country, subdivisions, city, location)

    Object.new.tap do |mmdb|
      mmdb.define_singleton_method(:local_ip_alias=) { |_| }
      mmdb.define_singleton_method(:lookup) do |_ip|
        on_lookup.yield
        result
      end
    end
  end

  def with_mmdb_available(mmdb)
    stubs = ActiveSupport::Testing::SimpleStubs.new
    stubs.stub_object(File, :exist?) { |path| path == MMDB_PATH }
    stubs.stub_object(MaxMindDB, :new) { |_path| mmdb }
    yield
  ensure
    stubs&.unstub_all!
  end
end
