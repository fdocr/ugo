# frozen_string_literal: true

module Ugo
  # Active Record pool size per process. Must be >= thread counts that use the DB
  # in that process (Puma: RAILS_MAX_THREADS; Solid Queue: SOLID_QUEUE_THREADS plus
  # worker and heartbeat threads — see SolidQueue::Configuration#estimated_number_of_threads).
  module DatabasePool
    # Solid Queue reserves two connections beyond configured worker threads.
    SOLID_QUEUE_OVERHEAD = 2

    module_function

    def size
      return ENV["DB_POOL"].to_i if ENV["DB_POOL"].present?

      [
        ENV.fetch("RAILS_MAX_THREADS", 3).to_i,
        ENV.fetch("SOLID_QUEUE_THREADS", 3).to_i + SOLID_QUEUE_OVERHEAD
      ].max
    end
  end
end
