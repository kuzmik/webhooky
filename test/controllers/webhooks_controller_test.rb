require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @token = Token.create!
  end

  test "captures a POST request" do
    post "/#{@token.uuid}", params: '{"event":"test"}',
      headers: { "Content-Type" => "application/json", "X-Custom" => "header-value" }

    assert_response :success
    assert_equal 1, @token.webhook_requests.count

    req = @token.webhook_requests.first
    assert_equal "POST", req.method_name
    assert_equal '{"event":"test"}', req.content
    assert_equal 16, req.content_size
  end

  test "captures a GET request" do
    get "/#{@token.uuid}?foo=bar&baz=qux"

    assert_response :success
    req = @token.webhook_requests.first
    assert_equal "GET", req.method_name
    parsed_query = JSON.parse(req.query)
    assert_equal "bar", parsed_query["foo"]
  end

  test "returns configured status code" do
    @token.update!(default_status: 201, default_content: '{"ok":true}', default_content_type: "application/json")

    post "/#{@token.uuid}", params: "test"
    assert_response 201
    assert_equal '{"ok":true}', response.body
    assert_equal "application/json", response.content_type.split(";").first
  end

  test "returns status override from URL" do
    post "/#{@token.uuid}/204", params: "test"
    assert_response 204
  end

  test "returns 404 for unknown token" do
    post "/00000000-0000-0000-0000-000000000000"
    assert_response :not_found
  end

  test "adds CORS headers when enabled" do
    @token.update!(cors: true)
    post "/#{@token.uuid}", params: "test"
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
  end

  test "stores headers as JSON" do
    post "/#{@token.uuid}", params: "x",
      headers: { "X-My-Header" => "my-value" }

    req = @token.webhook_requests.first
    headers = JSON.parse(req.headers)
    assert_equal "my-value", headers["x-my-header"]
  end

  test "enforces 1MB body limit" do
    big_body = "x" * (1.megabyte + 1)
    post "/#{@token.uuid}", params: big_body
    assert_response 413
  end

  test "cleans up oldest requests when over 500" do
    500.times do |i|
      @token.webhook_requests.create!(
        method_name: "GET", url: "/old", ip: "1.1.1.1",
        hostname: "localhost", headers: "{}", query: "{}",
        content_size: 0, created_at: i.minutes.ago
      )
    end

    assert_equal 500, @token.webhook_requests.count

    post "/#{@token.uuid}", params: "new"
    assert_equal 500, @token.webhook_requests.count
    assert_equal "POST", @token.webhook_requests.order(created_at: :desc).first.method_name
  end

  test "stores form data for form-encoded requests" do
    post "/#{@token.uuid}", params: { name: "test", value: "123" },
      headers: { "Content-Type" => "application/x-www-form-urlencoded" }

    req = @token.webhook_requests.first
    form = JSON.parse(req.form_data)
    assert_equal "test", form["name"]
  end
end
