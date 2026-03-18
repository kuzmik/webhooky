require "test_helper"

class TokenChannelTest < ActionCable::Channel::TestCase
  tests TokenChannel

  setup do
    @token = Token.create!
  end

  test "subscribes to token stream" do
    subscribe(token_uuid: @token.uuid)
    assert subscription.confirmed?
    assert_has_stream "token_#{@token.uuid}"
  end

  test "rejects subscription for missing token" do
    subscribe(token_uuid: "00000000-0000-0000-0000-000000000000")
    assert subscription.rejected?
  end
end
