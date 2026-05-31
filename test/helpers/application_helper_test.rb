# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "deep_link_bounce_example_url uses the configured domain and the bounce route" do
    config = AppConfig.new(app_domain: "ugo.cr")
    assert_equal "https://ugo.cr/r?r=", deep_link_bounce_example_url(config)
  end

  test "deep_link_bounce_example_url falls back to a placeholder domain" do
    config = AppConfig.new(app_domain: "")
    assert_equal "https://your-domain/r?r=", deep_link_bounce_example_url(config)
  end
end
