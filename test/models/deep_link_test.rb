# frozen_string_literal: true

require "test_helper"

class DeepLinkTest < ActiveSupport::TestCase
  test "track! creates a destination and records its host" do
    assert_difference "DeepLink.count", 1 do
      deep_link = DeepLink.track!("https://example.com/app")
      assert_equal "https://example.com/app", deep_link.destination_url
      assert_equal "example.com", deep_link.destination_host
    end
  end

  test "track! is idempotent and normalizes before matching" do
    first = DeepLink.track!("https://example.com/app")

    assert_no_difference "DeepLink.count" do
      # Fragment is stripped during normalization, so this is the same record.
      second = DeepLink.track!("https://example.com/app#section")
      assert_equal first.id, second.id
    end
  end

  test "visits are never discarded and analytics cache is namespaced" do
    deep_link = DeepLink.create!(destination_url: "https://example.com/app", destination_host: "example.com")
    assert_nil deep_link.visit_discard_reason
    assert_equal "deep_link_#{deep_link.id}_visits_charts", deep_link.analytics_cache_prefix
  end

  test "track! recovers from a concurrent insert race" do
    normalized = "https://race.example.com/app"
    existing = DeepLink.create!(destination_url: normalized, destination_host: "race.example.com")

    # Simulate another process inserting the row between our SELECT and INSERT:
    # find_or_create_by! raises RecordNotUnique and track! must fall back to a read.
    stubs = ActiveSupport::Testing::SimpleStubs.new
    stubs.stub_object(DeepLink, :find_or_create_by!) do |*, **|
      raise ActiveRecord::RecordNotUnique, "duplicate key value violates unique constraint"
    end

    result = nil
    assert_nothing_raised { result = DeepLink.track!(normalized) }
    assert_equal existing.id, result.id
  ensure
    stubs&.unstub_all!
  end
end
