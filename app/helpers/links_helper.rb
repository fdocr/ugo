module LinksHelper
  # Returns the host portion of a link's URL for display (e.g. "example.com"
  # from "https://example.com/path"). Falls back to the raw URL when the value
  # cannot be parsed as a URI so we never render a blank label.
  def link_host(url)
    URI.parse(url).host.presence || url
  rescue URI::InvalidURIError
    url
  end
end
