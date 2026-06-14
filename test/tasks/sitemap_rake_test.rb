# frozen_string_literal: true

require "test_helper"
require "rake"
require "zlib"

class SitemapRakeTest < ActiveSupport::TestCase
  def setup
    Rails.application.load_tasks
    @task = Rake::Task["sitemap:create"]
    @task.reenable

    @output_dir = Rails.root.join("tmp/sitemaps-#{Process.pid}-#{SecureRandom.hex(4)}")
    FileUtils.mkdir_p(@output_dir)
    SitemapGenerator::Sitemap.public_path = @output_dir.to_s
  end

  teardown do
    FileUtils.rm_rf(@output_dir)
    SitemapGenerator::Sitemap.public_path = "public/"
    @task.reenable
  end

  test "main app sitemap includes public marketing pages only" do
    setup_app_config_as_main_app!

    @task.invoke

    urls = sitemap_urls
    assert_includes urls, "https://ugo.cr"
    assert_includes urls, "https://ugo.cr/about"
    assert_includes urls, "https://ugo.cr/privacy"
    assert_includes urls, "https://ugo.cr/pricing"
    assert_includes urls, "https://ugo.cr/self-host"
    assert_includes urls, "https://ugo.cr/articles/open_beta"
    assert_includes urls, "https://ugo.cr/sign_up"

    assert_not_includes urls, "https://ugo.cr/dashboard"
    assert_not_includes urls, "https://ugo.cr/admin"
    assert_not_includes urls, "https://ugo.cr/setup"
  end

  test "self-hosted sitemap includes only the root URL" do
    setup_app_config_as_self_hosted!

    @task.invoke

    urls = sitemap_urls
    assert_equal [ "https://links.mycompany.com" ], urls

    assert_not_includes urls, "https://links.mycompany.com/privacy"
    assert_not_includes urls, "https://links.mycompany.com/about"
    assert_not_includes urls, "https://links.mycompany.com/pricing"
    assert_not_includes urls, "https://links.mycompany.com/self-host"
    assert_not_includes urls, "https://links.mycompany.com/articles/open_beta"
    assert_not_includes urls, "https://links.mycompany.com/sign_up"
  end

  private

  def sitemap_urls
    sitemap_file = Dir.glob(@output_dir.join("sitemap*.xml.gz")).first
    assert sitemap_file, "expected a compressed sitemap file in #{@output_dir}"

    xml = Zlib::GzipReader.open(sitemap_file, &:read)
    xml.scan(%r{<loc>(.*?)</loc>}).flatten
  end
end
