# frozen_string_literal: true

require "test_helper"

class UgoDatabasePoolTest < ActiveSupport::TestCase
  setup do
    @original_pool = ENV["DB_POOL"]
    @original_rails_threads = ENV["RAILS_MAX_THREADS"]
    @original_solid_threads = ENV["SOLID_QUEUE_THREADS"]
  end

  teardown do
    ENV["DB_POOL"] = @original_pool
    ENV["RAILS_MAX_THREADS"] = @original_rails_threads
    ENV["SOLID_QUEUE_THREADS"] = @original_solid_threads
  end

  test "size defaults to Solid Queue overhead when thread env vars are unset" do
    ENV.delete("DB_POOL")
    ENV.delete("RAILS_MAX_THREADS")
    ENV.delete("SOLID_QUEUE_THREADS")

    assert_equal 3 + Ugo::DatabasePool::SOLID_QUEUE_OVERHEAD, Ugo::DatabasePool.size
  end

  test "size returns max of RAILS_MAX_THREADS and Solid Queue thread estimate" do
    ENV.delete("DB_POOL")
    ENV["RAILS_MAX_THREADS"] = "5"
    ENV["SOLID_QUEUE_THREADS"] = "3"

    assert_equal 5, Ugo::DatabasePool.size
  end

  test "size uses Solid Queue thread estimate when larger than Puma threads" do
    ENV.delete("DB_POOL")
    ENV["RAILS_MAX_THREADS"] = "3"
    ENV["SOLID_QUEUE_THREADS"] = "8"

    assert_equal 10, Ugo::DatabasePool.size
  end

  test "size honors explicit DB_POOL" do
    ENV["DB_POOL"] = "10"
    ENV["RAILS_MAX_THREADS"] = "3"
    ENV["SOLID_QUEUE_THREADS"] = "3"

    assert_equal 10, Ugo::DatabasePool.size
  end
end
