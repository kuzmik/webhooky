require "test_helper"

class TokensControllerTest < ActionDispatch::IntegrationTest
  test "create makes a new token and redirects" do
    assert_difference -> { Token.count }, 1 do
      post "/tokens"
    end
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "update changes token settings" do
    token = Token.create!
    put "/tokens/#{token.uuid}", params: { default_status: 201, default_content: "created" }, as: :json
    assert_response :success

    token.reload
    assert_equal 201, token.default_status
    assert_equal "created", token.default_content
  end

  test "update rejects invalid settings" do
    token = Token.create!
    put "/tokens/#{token.uuid}", params: { default_status: 999 }, as: :json
    assert_response :unprocessable_entity
  end
end
