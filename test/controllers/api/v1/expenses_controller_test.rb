require "test_helper"

class Api::V1::ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test User",
      email: "expenses_test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    category = @user.categories.find_by!(name: "Groceries")

    3.times do |i|
      @user.expenses.create!(category: category, amount: 100 + i, description: "Item #{i}", expense_date: Date.current)
    end

    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    @token = JSON.parse(response.body)["token"]
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "index loads without N+1 queries (Bullet)" do
    get api_v1_expenses_url, headers: @headers
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 3, body["data"].size
    assert_kind_of Hash, body["meta"]
    assert_equal 3, body["meta"]["total"]
  end
end
