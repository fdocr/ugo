# frozen_string_literal: true

# Public marketing pages only — no authenticated app surfaces (dashboard,
# workspaces, admin, link redirects, etc.). Hosting mode controls which pages
# are actually exposed; see HomeController and ArticlesController.
config = AppConfig.shared
return unless config.setup_completed? && config.app_domain.present?

SitemapGenerator::Sitemap.default_host = "https://#{config.app_domain}"
SitemapGenerator::Sitemap.compress = true

SitemapGenerator::Sitemap.create do
  if AppConfig.main_app?
    add about_path, changefreq: "monthly", priority: 0.6
    add privacy_path, changefreq: "monthly", priority: 0.4
    add pricing_path, changefreq: "weekly", priority: 0.8
    add self_host_path, changefreq: "monthly", priority: 0.7
    add open_beta_article_path, changefreq: "monthly", priority: 0.5
    add sign_up_path, changefreq: "monthly", priority: 0.6
  else
    add privacy_path, changefreq: "monthly", priority: 0.4
  end
end

sitemap_url = "#{SitemapGenerator::Sitemap.default_host}/sitemap.xml.gz"
robots_path = Rails.root.join("public/robots.txt")
File.write(
  robots_path,
  <<~ROBOTS
    # See https://www.robotstxt.org/robotstxt.html for documentation on how to use the robots.txt file

    Sitemap: #{sitemap_url}
  ROBOTS
)
