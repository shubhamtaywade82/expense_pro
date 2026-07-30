require "test_helper"

class Api::V1::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "create registers a new user and returns token" do
    assert_difference("User.count", 1) do
      post api_v1_registrations_url, params: { user: { name: "New User", email: "new@example.com", password: "password123" } }
    end
    assert_response :created
    body = JSON.parse(response.body)
    assert body.key?("token")
    assert_equal "New User", body["name"]
  end

  test "create rejects duplicate email" do
    User.create!(name: "Existing", email: "dup@example.com", password: "password123", password_confirmation: "password123")
    post api_v1_registrations_url, params: { user: { name: "Duplicate", email: "dup@example.com", password: "password123" } }
    assert_response :unprocessable_entity
  end

  test "create rejects short password" do
    post api_v1_registrations_url, params: { user: { name: "Short", email: "short@example.com", password: "short" } }
    assert_response :unprocessable_entity
  end

  test "token from registration works for authenticated requests" do
    post api_v1_registrations_url, params: { user: { name: "Fresh", email: "fresh@example.com", password: "password123" } }
    token = JSON.parse(response.body)["token"]

    get api_v1_session_url, headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
  end
end
