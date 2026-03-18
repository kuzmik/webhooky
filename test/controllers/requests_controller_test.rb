require "test_helper"

class RequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @token = Token.create!
    @req = @token.webhook_requests.create!(
      method_name: "POST",
      url: "/test",
      ip: "127.0.0.1",
      hostname: "localhost",
      headers: '{"content-type":"application/json"}',
      query: '{"page":"1"}',
      content: '{"hello":"world"}',
      content_size: 17
    )
  end

  test "index returns paginated requests" do
    get "/tokens/#{@token.uuid}/requests"
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 1, json["total"]
    assert_equal 1, json["data"].length
    assert_equal "POST", json["data"][0]["method_name"]
  end

  test "show returns single request" do
    get "/tokens/#{@token.uuid}/requests/#{@req.uuid}"
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal "POST", json["method_name"]
    assert_equal '{"hello":"world"}', json["content"]
  end

  test "destroy deletes a request" do
    assert_difference -> { WebhookRequest.count }, -1 do
      delete "/tokens/#{@token.uuid}/requests/#{@req.uuid}"
    end
    assert_response :no_content
  end

  test "destroy_all deletes all requests for token" do
    @token.webhook_requests.create!(
      method_name: "GET", url: "/2", ip: "1.1.1.1",
      hostname: "localhost", headers: "{}", query: "{}", content_size: 0
    )

    assert_difference -> { WebhookRequest.count }, -2 do
      delete "/tokens/#{@token.uuid}/requests"
    end
    assert_response :no_content
  end
end
