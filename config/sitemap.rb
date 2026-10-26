# frozen_string_literal: true

# Public marketing pages only — no authenticated app surfaces (dashboard,
# workspaces, admin, link redirects, etc.). Hosting mode controls which pages
# are actually exposed; see HomeController and ArticlesController.
config = AppConfig.shared
return unless config.setup_completed? && config.app_domain.present?

SitemapGenerator::Sitemap.default_host = "https://#{config.app_domain}"
SitemapGenerator::Sitemap.compress = true

SitemapGenerator::Sitemap.create do
  next unless AppConfig.main_app?

  add about_path, changefreq: "monthly", priority: 0.6
  add privacy_path, changefreq: "monthly", priority: 0.4
  add pricing_path, changefreq: "weekly", priority: 0.8
  add self_host_path, changefreq: "monthly", priority: 0.7
  add open_beta_article_path, changefreq: "monthly", priority: 0.5
  add sign_up_path, changefreq: "monthly", priority: 0.6
end
