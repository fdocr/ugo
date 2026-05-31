module ApplicationHelper
  # Example bounce URL shown in admin settings, e.g. https://ugo.cr/r?r=
  # Uses the route helper so the path stays in sync with config/routes.rb.
  def deep_link_bounce_example_url(config = AppConfig.shared)
    domain = config.app_domain.presence || "your-domain"
    "#{deep_link_bounce_url(host: domain, protocol: 'https')}?r="
  end
end
