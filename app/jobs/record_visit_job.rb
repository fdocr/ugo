# Persists a click as a Visit row off the request thread. Solid Queue is backed
# by its own SQLite database (`storage/*_queue.sqlite3`), so enqueuing from the
# redirect controller costs a write to the queue DB only — the primary DB
# writer lock stays free for user-driven actions.
class RecordVisitJob < ApplicationJob
  queue_as :visits

  # A persisted visitable (e.g. a Link) is delivered by GlobalID and may be
  # deleted between enqueue and perform; drop the click instead of retrying a
  # record that can no longer be deserialized.
  discard_on ActiveJob::DeserializationError

  def perform(ip_address:, user_agent:, referer:, timestamp:, visitable: nil, visitable_url: nil)
    visitable = resolve_visitable(visitable, visitable_url)
    return unless visitable

    Visit.create!(
      visitable: visitable,
      ip_address: ip_address,
      user_agent: user_agent,
      referer: referer,
      timestamp: timestamp,
      visitor_hash: VisitorHash.compute(
        ip: ip_address,
        user_agent: user_agent,
        visitable_type: visitable.class.name,
        visitable_id: visitable.id,
        at: timestamp
      )
    )
  end

  private

  # Persisted visitables arrive as the record itself (via GlobalID). Deep links
  # don't exist at enqueue time, so they're created/found here by destination
  # URL — keeping the bounce hot path free of primary-DB writes.
  def resolve_visitable(visitable, url)
    return visitable if visitable

    DeepLink.track!(url) if url.present?
  end
end
