class Link < ApplicationRecord
  belongs_to :workspace

  has_one :social_tag, dependent: :destroy
  has_many :visits, as: :visitable, dependent: :destroy

  validates :name, length: { maximum: 255 }, allow_blank: true
  validates :url, length: { maximum: 2048 }, allow_nil: true
  validates_with HttpUrlValidator, attributes: [ :url ]

  after_commit :sync_social_tag
  after_create :draw_qr_code
  after_update :draw_qr_code, if: :saved_change_to_url?
  before_validation :ensure_default_name, on: :create
  before_update :ensure_default_name, if: :name_changed_and_blank?

  def domain_url
    "#{AppConfig.shared.app_domain}/#{slug}"
  end

  def event_limit_reached?
    workspace.event_limit_reached?
  end

  # ---- Visit processing (see ProcessVisitsJob) ----------------------------

  # Reason to drop a queued visit during processing, or nil to keep it. Visits
  # for disabled or over-limit workspaces are discarded rather than enriched.
  def visit_discard_reason
    return "workspace #{workspace_id} disabled (trial ended)" if workspace.ugo_access_blocked?
    return "workspace #{workspace_id} reached its limit" if workspace.event_limit_reached?

    nil
  end

  # Cache namespace for this visitable's analytics charts (see VisitsController).
  def analytics_cache_prefix
    "#{id}_visits_charts"
  end

  def banned?
    banned_at.present?
  end

  def save_with_new_slug
    attempts = 0
    begin
      self.slug = "#{rand(0..9)}#{SecureRandom.alphanumeric(4)}"
      attempts += 1
    end while !save && attempts < 50

    unless self.persisted?
      errors.add(:base, "Failed to create link. Please try again.")
    end
  end

  private

  def ensure_default_name
    self.name = "Unnamed Link" if name.blank?
  end

  def name_changed_and_blank?
    will_save_change_to_name? && name.blank?
  end

  def sync_social_tag
    SyncSocialTagJob.perform_later(slug: slug)
  end

  def draw_qr_code
    return if url.blank?

    self.qr_code = RQRCode::QRCode.new(url).as_svg(
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 11,
      standalone: true,
      use_path: true
    )
    save
  end
end
