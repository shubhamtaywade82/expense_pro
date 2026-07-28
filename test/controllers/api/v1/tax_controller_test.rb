require "test_helper"

class Api::V1::TaxControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test User",
      email: "tax_test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    2.times do |i|
      @user.investments.create!(
        name: "Position #{i}",
        asset_class: %w[speculative_intraday non_speculative_fo].sample,
        quantity: 10,
        buy_price: 100,
        sell_price: 120,
        purchase_date: 6.months.ago.to_date,
        sell_date: 1.month.ago.to_date,
        status: "realized"
      )
    end

    @user.incomes.create!(source: "Salary", amount: 80_000, income_date: Date.current, is_recurring: true, frequency: "monthly")

    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    @token = JSON.parse(response.body)["token"]
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "itr_summary loads without N+1 queries (Bullet)" do
    get api_v1_tax_itr_summary_url, params: { financial_year: Date.current.year }, headers: @headers
    assert_response :success
  end
end
