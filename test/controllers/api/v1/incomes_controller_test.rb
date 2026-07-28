require "test_helper"

class Api::V1::IncomesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test User",
      email: "incomes_test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    3.times do |i|
      @user.incomes.create!(source: "Source #{i}", amount: 1000 + i, income_date: Date.current, is_recurring: false)
    end

    2.times do |i|
      @user.incomes.create!(
        source: "Recurring #{i}", amount: 2000 + i, income_date: 3.months.ago.to_date,
        is_recurring: true, frequency: "monthly"
      )
    end

    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    @token = JSON.parse(response.body)["token"]
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "index loads without N+1 queries (Bullet)" do
    get api_v1_incomes_url, headers: @headers
    assert_response :success
  end

  test "index with month/year (recurring projections) loads without N+1 queries (Bullet)" do
    get api_v1_incomes_url, params: { month: Date.current.month, year: Date.current.year }, headers: @headers
    assert_response :success
  end

  test "yearly summary loads without N+1 queries (Bullet)" do
    get yearly_api_v1_incomes_url, params: { year: Date.current.year }, headers: @headers
    assert_response :success
  end
end
