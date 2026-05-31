class SyncSocialTagJob < ApplicationJob
  queue_as :default

  USER_AGENT = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3.1 Mobile/15E148 Safari/604.1".freeze
  REDIRECT_LIMIT = 2
  OPEN_TIMEOUT = 5
  TIMEOUT = 10
  MAX_BODY_BYTES = 2_000_000

  def perform(slug:)
    link = Link.find_by(slug: slug)
    return unless link&.url.present?

    response = http.get(link.url)

    unless response.success?
      Rails.logger.info "Failed to sync social tags for link #{slug} (#{link.url}): #{response.status}"
      return
    end

    parse_and_persist(link, response.body.to_s.byteslice(0, MAX_BODY_BYTES), response.env.url)
  rescue Faraday::Error => e
    Rails.logger.error "Failed to sync social tags for link #{slug} (#{link&.url}): #{e.message}"
  end

  private

  def http
    @http ||= Faraday.new(
      headers: { "User-Agent" => USER_AGENT },
      request: { open_timeout: OPEN_TIMEOUT, timeout: TIMEOUT }
    ) do |f|
      f.response :follow_redirects, limit: REDIRECT_LIMIT
      f.adapter Faraday.default_adapter
    end
  end

  def parse_and_persist(link, body, final_url)
    social_tag = link.social_tag || SocialTag.new(link: link)
    doc = Nokogiri::HTML(body)
    base_url = document_base_url(doc, final_url)

    title = doc.at_css('meta[property="og:title"]')&.[]("content")
    title = doc.at_css('meta[name="twitter:title"]')&.[]("content") if title.blank?
    social_tag.title = title unless title.blank?

    url = doc.at_css('meta[property="og:url"]')&.[]("content")
    url = doc.at_css('meta[name="twitter:url"]')&.[]("content") if url.blank?
    social_tag.url = absolutize(url, base_url) unless url.blank?

    image = doc.at_css('meta[property="og:image"]')&.[]("content")
    image = doc.at_css('meta[name="twitter:image"]')&.[]("content") if image.blank?
    social_tag.image_url = absolutize(image, base_url) unless image.blank?

    description = doc.at_css('meta[property="og:description"]')&.[]("content")
    description = doc.at_css('meta[name="twitter:description"]')&.[]("content") if description.blank?
    social_tag.description = description unless description.blank?

    social_tag.save if social_tag.changed?
  end

  # Browsers resolve relative URLs against `<base href>` if present, falling
  # back to the document's final URL after redirects. Return a URI we can pass
  # to URI#+ (a.k.a. URI.join).
  def document_base_url(doc, final_url)
    base_href = doc.at_css("base[href]")&.[]("href")
    return final_url if base_href.blank?

    URI.join(final_url, base_href)
  rescue URI::InvalidURIError
    final_url
  end

  # Resolve a (possibly relative, protocol-relative, or absolute) URL against
  # the document's base. Returns the original string unchanged if parsing
  # fails so we don't accidentally drop a usable value.
  def absolutize(href, base_url)
    URI.join(base_url, href).to_s
  rescue URI::InvalidURIError
    href
  end
end
