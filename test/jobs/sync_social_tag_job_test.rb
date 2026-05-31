require "test_helper"

class SyncSocialTagJobTest < ActiveJob::TestCase
  setup do
    setup_app_config_as_main_app!
    @link = links(:one)
    @link.social_tag&.destroy
    @link.reload
  end

  test "200 OK with OG meta tags creates a SocialTag with the parsed fields" do
    body = html_with_og(
      title: "Hello world",
      description: "A friendly page",
      url: "https://example.com/hello",
      image: "https://example.com/hero.png"
    )
    run_job_with_stubs do |stubs|
      stubs.get(@link.url) { [ 200, { "Content-Type" => "text/html" }, body ] }
    end

    tag = @link.reload.social_tag
    assert_not_nil tag
    assert_equal "Hello world", tag.title
    assert_equal "A friendly page", tag.description
    assert_equal "https://example.com/hello", tag.url
    assert_equal "https://example.com/hero.png", tag.image_url
  end

  test "follows a 301 redirect and parses the final response" do
    final_url = "https://example.com/final"
    body = html_with_og(title: "Final destination")

    run_job_with_stubs do |stubs|
      stubs.get(@link.url) { [ 301, { "Location" => final_url }, "" ] }
      stubs.get(final_url) { [ 200, { "Content-Type" => "text/html" }, body ] }
    end

    tag = @link.reload.social_tag
    assert_not_nil tag
    assert_equal "Final destination", tag.title
  end

  test "redirect chain longer than the limit is rescued and logged, no SocialTag created" do
    hop1 = "https://example.com/hop1"
    hop2 = "https://example.com/hop2"
    hop3 = "https://example.com/hop3"

    logs = capture_logs do
      run_job_with_stubs do |stubs|
        stubs.get(@link.url) { [ 301, { "Location" => hop1 }, "" ] }
        stubs.get(hop1)      { [ 301, { "Location" => hop2 }, "" ] }
        stubs.get(hop2)      { [ 301, { "Location" => hop3 }, "" ] }
      end
    end

    assert_nil @link.reload.social_tag
    assert_match(/Failed to sync social tags/, logs)
  end

  test "non-2xx final response logs and does not create a SocialTag" do
    logs = capture_logs do
      run_job_with_stubs do |stubs|
        stubs.get(@link.url) { [ 404, {}, "" ] }
      end
    end

    assert_nil @link.reload.social_tag
    assert_match(/Failed to sync social tags.*404/, logs)
  end

  test "body larger than MAX_BODY_BYTES is truncated before parsing" do
    head = html_with_og(title: "Visible title")
    sentinel = '<meta property="og:description" content="HIDDEN_SENTINEL">'
    padding = " " * (SyncSocialTagJob::MAX_BODY_BYTES + 1_000)
    body = head + padding + sentinel + "</head></html>"

    run_job_with_stubs do |stubs|
      stubs.get(@link.url) { [ 200, { "Content-Type" => "text/html" }, body ] }
    end

    tag = @link.reload.social_tag
    assert_not_nil tag
    assert_equal "Visible title", tag.title
    assert_not_equal "HIDDEN_SENTINEL", tag.description
  end

  test "resolves a relative og:image against the response URL" do
    body = html_with_og(image: "/assets/og_banner.png")
    run_job_with_stubs do |stubs|
      stubs.get(@link.url) { [ 200, { "Content-Type" => "text/html" }, body ] }
    end

    assert_equal "https://example.com/assets/og_banner.png", @link.reload.social_tag.image_url
  end

  test "resolves a relative og:image against the final URL after redirects" do
    final_url = "https://blog.example.com/posts/hello"
    body = html_with_og(image: "../static/og.png")

    run_job_with_stubs do |stubs|
      stubs.get(@link.url) { [ 301, { "Location" => final_url }, "" ] }
      stubs.get(final_url) { [ 200, { "Content-Type" => "text/html" }, body ] }
    end

    assert_equal "https://blog.example.com/static/og.png", @link.reload.social_tag.image_url
  end

  test "respects a <base href> when resolving relative URLs" do
    body = <<~HTML
      <html><head>
        <base href="https://cdn.example.com/site/">
        <meta property="og:image" content="img/banner.png">
        <meta property="og:url" content="page.html">
      </head></html>
    HTML

    run_job_with_stubs do |stubs|
      stubs.get(@link.url) { [ 200, { "Content-Type" => "text/html" }, body ] }
    end

    tag = @link.reload.social_tag
    assert_equal "https://cdn.example.com/site/img/banner.png", tag.image_url
    assert_equal "https://cdn.example.com/site/page.html", tag.url
  end

  test "leaves an already-absolute og:image untouched" do
    body = html_with_og(image: "https://cdn.example.com/banner.png")
    run_job_with_stubs do |stubs|
      stubs.get(@link.url) { [ 200, { "Content-Type" => "text/html" }, body ] }
    end

    assert_equal "https://cdn.example.com/banner.png", @link.reload.social_tag.image_url
  end

  test "resolves a protocol-relative og:image against the response scheme" do
    body = html_with_og(image: "//cdn.example.com/banner.png")
    run_job_with_stubs do |stubs|
      stubs.get(@link.url) { [ 200, { "Content-Type" => "text/html" }, body ] }
    end

    assert_equal "https://cdn.example.com/banner.png", @link.reload.social_tag.image_url
  end

  test "is a no-op when the link has been deleted between enqueue and perform" do
    assert_nothing_raised do
      SyncSocialTagJob.perform_now(slug: "does-not-exist")
    end
  end

  private

  def html_with_og(title: nil, description: nil, url: nil, image: nil)
    tags = []
    tags << %(<meta property="og:title" content="#{title}">) if title
    tags << %(<meta property="og:description" content="#{description}">) if description
    tags << %(<meta property="og:url" content="#{url}">) if url
    tags << %(<meta property="og:image" content="#{image}">) if image
    "<html><head>#{tags.join}</head><body></body></html>"
  end

  def run_job_with_stubs
    stubs = Faraday::Adapter::Test::Stubs.new
    yield stubs

    connection = Faraday.new(headers: { "User-Agent" => SyncSocialTagJob::USER_AGENT }) do |f|
      f.response :follow_redirects, limit: SyncSocialTagJob::REDIRECT_LIMIT
      f.adapter :test, stubs
    end

    job = SyncSocialTagJob.new
    job.instance_variable_set(:@http, connection)
    job.perform(slug: @link.slug)

    stubs.verify_stubbed_calls
  end

  def capture_logs
    io = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original_logger
  end
end
