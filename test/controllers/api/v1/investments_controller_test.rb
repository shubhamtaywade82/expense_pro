require "test_helper"

class Api::V1::InvestmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test User",
      email: "investments_test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    3.times do |i|
      @user.investments.create!(
        name: "Position #{i}",
        asset_class: "long_term_equity",
        quantity: 10,
        buy_price: 100,
        current_price: 110,
        purchase_date: 6.months.ago.to_date,
        status: "active"
      )
    end

    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    @token = JSON.parse(response.body)["token"]
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "index loads without N+1 queries (Bullet)" do
    get api_v1_investments_url, headers: @headers
    assert_response :success
    assert_equal 3, JSON.parse(response.body)["investments"].size
  end
end
