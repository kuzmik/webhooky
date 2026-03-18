require "test_helper"

class WebhookRequestTest < ActiveSupport::TestCase
  setup do
    @token = Token.create!
  end

  test "generates uuid on create" do
    req = @token.webhook_requests.create!(
      method_name: "POST",
      url: "/test",
      ip: "127.0.0.1",
      hostname: "localhost",
      headers: "{}",
      query: "{}",
      content: '{"hello":"world"}',
      content_size: 17
    )
    assert_match(/\A[0-9a-f]{8}-/, req.uuid)
  end

  test "belongs to token" do
    req = @token.webhook_requests.create!(
      method_name: "GET",
      url: "/test",
      ip: "127.0.0.1",
      hostname: "localhost",
      headers: "{}",
      query: "{}",
      content_size: 0
    )
    assert_equal @token, req.token
  end

  test "validates required fields" do
    req = WebhookRequest.new
    assert_not req.valid?
    assert_includes req.errors[:method_name], "can't be blank"
    assert_includes req.errors[:url], "can't be blank"
    assert_includes req.errors[:ip], "can't be blank"
  end

  test "can order by created_at desc" do
    old = @token.webhook_requests.create!(
      method_name: "GET", url: "/1", ip: "1.1.1.1",
      hostname: "localhost", headers: "{}", query: "{}", content_size: 0,
      created_at: 2.minutes.ago
    )
    new_req = @token.webhook_requests.create!(
      method_name: "POST", url: "/2", ip: "2.2.2.2",
      hostname: "localhost", headers: "{}", query: "{}", content_size: 0,
      created_at: 1.minute.ago
    )
    assert_equal [new_req, old], @token.webhook_requests.order(created_at: :desc).to_a
  end
end
