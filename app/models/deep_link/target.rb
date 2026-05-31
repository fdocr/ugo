# frozen_string_literal: true

class DeepLink
  # Value object for a candidate bounce destination: the raw `?r=` parameter (or
  # the configured default) before it becomes a DeepLink record. Parses the URL
  # exactly once and answers what the bounce needs — the normalized form, the
  # host, and whether it clears the optional domain allowlist. The "http(s) +
  # host" rule and the parse itself are owned by HttpUrlValidator.
  class Target
    class InvalidTarget < StandardError; end

    def initialize(url)
      @raw = url.to_s.strip
    end

    # Validated, fragment-stripped URL string. Raises InvalidTarget when the
    # input isn't a usable http(s) URL.
    def url
      raise InvalidTarget, "URL is required" if @raw.blank?
      raise InvalidTarget, parse_error if parse_error

      normalized = uri.dup
      normalized.fragment = nil
      normalized.to_s
    end

    # Lowercased host of the target, or nil when it can't be parsed.
    def host
      uri&.host&.downcase
    end

    # True when the target host matches the allowlist. Reuses the single parse so
    # the bounce never normalizes the URL more than once.
    def allowed?(domains:)
      return false if uri.nil? || uri.host.blank?

      target_host = uri.host.downcase
      allowed_hosts(domains).any? { |allowed| target_host == allowed || target_host.end_with?(".#{allowed}") }
    end

    private

    def parsed
      @parsed ||= HttpUrlValidator.parse(@raw)
    end

    def uri
      parsed.first
    end

    def parse_error
      parsed.last
    end

    def allowed_hosts(domains)
      domains.to_s.split(/[\s,]+/).map { |d| d.strip.downcase.delete_prefix("www.") }.reject(&:blank?)
    end
  end
end
