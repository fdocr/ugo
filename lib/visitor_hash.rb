# Computes a per-visit pseudonymous identifier used by analytics to estimate
# unique visitors without storing a long-lived cookie or any reversible PII.
#
# The hash is HMAC-SHA256 over the visitor's IP, User-Agent, and the visitable,
# keyed by a daily-rotated salt derived from the application's secret_key_base.
module VisitorHash
  LENGTH = 32

  def self.compute(ip:, user_agent:, visitable_type:, visitable_id:, at: Time.current)
    return nil if ip.blank?

    OpenSSL::HMAC.hexdigest(
      "SHA256",
      daily_salt(at),
      "#{ip}|#{user_agent}|#{visitable_type}|#{visitable_id}"
    ).first(LENGTH)
  end

  def self.daily_salt(at)
    "ugo-visitor-hash:#{at.utc.to_date.iso8601}:#{Rails.application.secret_key_base}"
  end
  private_class_method :daily_salt
end
