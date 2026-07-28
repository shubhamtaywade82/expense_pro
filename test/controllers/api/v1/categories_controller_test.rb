require "test_helper"

class Api::V1::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test User",
      email: "categories_test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    @token = JSON.parse(response.body)["token"]
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "index loads without N+1 queries (Bullet)" do
    get api_v1_categories_url, headers: @headers
    assert_response :success
  end
end
