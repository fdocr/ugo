require "test_helper"

class Api::LinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @workspace_one = workspaces(:one)
    @workspace_two = workspaces(:two)
    @link_one = links(:one)
    @link_two = links(:two)
    @admin_api_key = AppConfig.shared.admin_api_key
  end

  test "should return 401 when no API key is provided" do
    get api_link_url(@link_one.slug)

    assert_response :unauthorized
    assert_equal({ "error" => "Not Authorized" }, JSON.parse(response.body))
  end

  test "should return 401 when invalid API key is provided" do
    get api_link_url(@link_one.slug), headers: { "X-Api-Key" => "invalid-token" }

    assert_response :unauthorized
    assert_equal({ "error" => "Not Authorized" }, JSON.parse(response.body))
  end

  test "should return link when valid workspace API key is provided for own link" do
    get api_link_url(@link_one.slug), headers: { "X-Api-Key" => @workspace_one.api_token }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal @link_one.slug, response_data["slug"]
    assert_equal @link_one.url, response_data["url"]
    assert_equal @link_one.workspace.domain, response_data["domain"]
  end

  test "should return 404 when workspace API key tries to access link from different workspace" do
    get api_link_url(@link_two.slug), headers: { "X-Api-Key" => @workspace_one.api_token }

    assert_response :not_found
    assert_equal({ "error" => "Link not found" }, JSON.parse(response.body))
  end

  test "should return link when admin API key is provided for any link" do
    get api_link_url(@link_one.slug), headers: { "X-Api-Key" => @admin_api_key }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal @link_one.slug, response_data["slug"]
    assert_equal @link_one.url, response_data["url"]
    assert_equal @link_one.workspace.domain, response_data["domain"]
  end

  test "should return link from different workspace when admin API key is provided" do
    get api_link_url(@link_two.slug), headers: { "X-Api-Key" => @admin_api_key }

    assert_response :success
    response_data = JSON.parse(response.body)
    assert_equal @link_two.slug, response_data["slug"]
    assert_equal @link_two.url, response_data["url"]
    assert_equal @link_two.workspace.domain, response_data["domain"]
  end

  test "should return 404 when link does not exist" do
    get api_link_url("non-existent-slug"), headers: { "X-Api-Key" => @workspace_one.api_token }

    assert_response :not_found
    assert_equal({ "error" => "Link not found" }, JSON.parse(response.body))
  end

  test "should return 404 when admin API key is used but link does not exist" do
    get api_link_url("non-existent-slug"), headers: { "X-Api-Key" => @admin_api_key }

    assert_response :not_found
    assert_equal({ "error" => "Link not found" }, JSON.parse(response.body))
  end

  test "should return 429 after exceeding API rate limit" do
    60.times do
      get api_link_url(@link_one.slug), headers: { "X-Api-Key" => @workspace_one.api_token }
      assert_response :success
    end

    get api_link_url(@link_one.slug), headers: { "X-Api-Key" => @workspace_one.api_token }
    assert_response :too_many_requests
    assert_equal({ "error" => "Rate limit exceeded" }, JSON.parse(response.body))
  end
end
