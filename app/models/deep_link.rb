# frozen_string_literal: true

class DeepLink < ApplicationRecord
  has_many :visits, as: :visitable, dependent: :destroy

  validates :destination_url, presence: true, uniqueness: true
  validates :destination_host, presence: true

  # Resolves the canonical DeepLink for a destination, creating it on first
  # sight. Safe to call concurrently: the unique index on destination_url means
  # a racing insert raises RecordNotUnique, which we recover from by reading the
  # row the other process just wrote.
  def self.track!(url)
    target = Target.new(url)
    normalized = target.url

    find_or_create_by!(destination_url: normalized) do |deep_link|
      deep_link.destination_host = target.host
    end
  rescue ActiveRecord::RecordNotUnique
    find_by!(destination_url: normalized)
  end

  # ---- Visit processing (see ProcessVisitsJob) ----------------------------

  # Deep link bounces are never gated by workspace limits, so visits are always
  # kept for enrichment.
  def visit_discard_reason
    nil
  end

  # Cache namespace for this visitable's analytics charts.
  def analytics_cache_prefix
    "deep_link_#{id}_visits_charts"
  end
end
