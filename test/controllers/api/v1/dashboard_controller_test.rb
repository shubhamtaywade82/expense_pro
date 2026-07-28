require "test_helper"

class Api::V1::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test User",
      email: "dashboard_test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    loan_category = @user.categories.find_by!(name: "Personal Loan")
    expense_category = @user.categories.find_by!(name: "Groceries")

    2.times do |i|
      loan = @user.loans.create!(
        category: loan_category,
        name: "Loan #{i}",
        lender: "Bank #{i}",
        principal_amount: 100_000,
        interest_rate: 8.5,
        tenure_months: 12,
        start_date: 1.year.ago.to_date,
        loan_type: "personal"
      )
      loan.emi_payments.first.mark_paid!
    end

    2.times do |i|
      @user.expenses.create!(category: expense_category, amount: 500 + i, description: "Item #{i}", expense_date: Date.current)
    end

    @user.incomes.create!(source: "Salary", amount: 50_000, income_date: Date.current, is_recurring: true, frequency: "monthly")

    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    @token = JSON.parse(response.body)["token"]
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "overview loads without N+1 queries (Bullet)" do
    get api_v1_dashboard_overview_url, headers: @headers
    assert_response :success
  end
end
