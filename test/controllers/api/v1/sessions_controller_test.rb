require "test_helper"

class Api::V1::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Test User", email: "session_test@example.com", password: "password123", password_confirmation: "password123")
  end

  test "create returns token with valid credentials" do
    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    assert_response :success
    body = JSON.parse(response.body)
    assert body.key?("token")
    assert_equal @user.email, body["email"]
  end

  test "create rejects invalid password" do
    post api_v1_session_url, params: { email: @user.email, password: "wrong" }
    assert_response :unauthorized
  end

  test "show returns user when authenticated" do
    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    token = JSON.parse(response.body)["token"]

    get api_v1_session_url, headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    assert_equal @user.email, JSON.parse(response.body)["email"]
  end

  test "destroy revokes all tokens" do
    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    old_token = JSON.parse(response.body)["token"]

    delete api_v1_session_url, headers: { "Authorization" => "Bearer #{old_token}" }
    assert_response :no_content

    get api_v1_session_url, headers: { "Authorization" => "Bearer #{old_token}" }
    assert_response :unauthorized
  end
end
