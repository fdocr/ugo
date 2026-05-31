# frozen_string_literal: true

# Validates that an attribute is a syntactically valid http(s) URL with a host.
# Shared by Link#url and AppConfig#deep_link_default_destination so the "http or
# https + host present" rule lives in exactly one place.
#
# Attach it with validates_with, which references this class directly. (The
# `http_url: true` shorthand resolves the validator by name at load time, which
# can race the autoloader on the first request after a development reload.)
#
#   validates_with HttpUrlValidator, attributes: [ :url ]
class HttpUrlValidator < ActiveModel::EachValidator
  ALLOWED_SCHEMES = %w[http https].freeze

  # Single source of truth for the "http(s) URL with a host" rule. Parses value
  # once and returns a [uri, error_message] pair where error_message is nil when
  # the URL is usable. Reused by DeepLink::Target so the rule (and the single
  # parse) is not duplicated.
  def self.parse(value)
    uri = URI.parse(value.to_s)
    return [ uri, "must use http or https" ] unless ALLOWED_SCHEMES.include?(uri.scheme&.downcase)
    return [ uri, "is not a valid URL" ] if uri.host.blank?

    [ uri, nil ]
  rescue URI::InvalidURIError
    [ nil, "is not a valid URL" ]
  end

  def validate_each(record, attribute, value)
    return if value.blank?

    _uri, error = self.class.parse(value)
    record.errors.add(attribute, error) if error
  end
end
