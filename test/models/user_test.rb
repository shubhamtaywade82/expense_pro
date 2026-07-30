require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Test User", email: "user_test@example.com", password: "password123", password_confirmation: "password123")
  end

  test "token is valid when never revoked" do
    assert @user.token_valid?(100)
  end

  test "token issued before revocation is invalid" do
    @user.revoke_all_tokens!
    assert_not @user.token_valid?(1.minute.ago.to_i)
  end

  test "token issued after revocation is valid" do
    @user.revoke_all_tokens!
    assert @user.token_valid?(1.minute.from_now.to_i)
  end
end
