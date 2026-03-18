require "test_helper"

class TokenTest < ActiveSupport::TestCase
  test "generates uuid on create" do
    token = Token.create!
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i, token.uuid)
  end

  test "has default response settings" do
    token = Token.create!
    assert_equal 200, token.default_status
    assert_equal "application/json", token.default_content_type
    assert_equal "", token.default_content
    assert_equal true, token.cors
  end

  test "validates default_status is between 100 and 599" do
    token = Token.new(default_status: 999)
    assert_not token.valid?
    assert token.errors[:default_status].any?
  end

  test "validates timeout is at most 10" do
    token = Token.new(timeout: 30)
    assert_not token.valid?
    assert_includes token.errors[:timeout], "must be less than or equal to 10"
  end

  test "timeout can be nil" do
    token = Token.new(timeout: nil)
    token.valid?
    assert_empty token.errors[:timeout]
  end
end
