require "test_helper"

class DhanTokenServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Dhan Test User",
      email: "dhan_token_test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    Current.user = @user
    @original_env = ENV.to_hash
  end

  teardown do
    Current.reset
    ENV.replace(@original_env)
  end

  test "current_token! returns the DB-cached token without hitting the network" do
    DhanAccessToken.create!(user: @user, access_token: "cached-token", expires_at: 1.hour.from_now)

    assert_equal "cached-token", DhanTokenService.current_token!
  end

  test "fetch_and_store! falls back to DHAN_ACCESS_TOKEN when no credential is configured" do
    ENV["DHAN_TOKEN_ACCESS_TOKEN"] = nil
    ENV["DHAN_ACCESS_TOKEN"] = "env-token"

    token = DhanTokenService.fetch_and_store!
    assert_equal "env-token", token
    assert DhanAccessToken.active(@user).present?
  end

  test "fetch_and_store! raises TokenUnavailableError when nothing is configured" do
    ENV["DHAN_ACCESS_TOKEN"] = nil
    ENV["ACCESS_TOKEN"] = nil
    ENV["DHAN_TOKEN_ACCESS_TOKEN"] = nil

    assert_raises(DhanTokenService::TokenUnavailableError) do
      DhanTokenService.fetch_and_store!
    end
  end

  test "fetch_and_store! raises UserRequiredError when no current user is set" do
    Current.user = nil

    assert_raises(DhanTokenService::UserRequiredError) do
      DhanTokenService.fetch_and_store!
    end
  end

  test "DhanCredential fallback_access_token takes precedence over ENV" do
    ENV["DHAN_ACCESS_TOKEN"] = "env-token"
    DhanCredential.create!(user: @user, fallback_access_token: "credential-token")

    token = DhanTokenService.fetch_and_store!
    assert_equal "credential-token", token
  end

  test "tokens are isolated per user" do
    other_user = User.create!(
      name: "Other User",
      email: "dhan_token_test_other@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    DhanAccessToken.create!(user: other_user, access_token: "other-users-token", expires_at: 1.hour.from_now)

    assert_nil DhanAccessToken.active(@user)
  end
end
