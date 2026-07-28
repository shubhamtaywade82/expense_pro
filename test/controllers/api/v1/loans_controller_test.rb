require "test_helper"

class Api::V1::LoansControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test User",
      email: "loans_test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @category = @user.categories.find_by!(name: "Personal Loan")

    3.times do |i|
      @user.loans.create!(
        category: @category,
        name: "Loan #{i}",
        lender: "Bank #{i}",
        principal_amount: 100_000,
        interest_rate: 8.5,
        tenure_months: 12,
        start_date: 1.year.ago.to_date,
        loan_type: "personal"
      )
    end

    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    @token = JSON.parse(response.body)["token"]
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "index query count does not grow with the number of loans" do
    queries_for_three = count_queries { get api_v1_loans_url, headers: @headers }
    assert_response :success
    assert_equal 3, JSON.parse(response.body).size

    @user.loans.create!(
      category: @category,
      name: "Loan extra",
      lender: "Bank extra",
      principal_amount: 50_000,
      interest_rate: 8.5,
      tenure_months: 12,
      start_date: 1.year.ago.to_date,
      loan_type: "personal"
    )

    queries_for_four = count_queries { get api_v1_loans_url, headers: @headers }
    assert_response :success
    assert_equal 4, JSON.parse(response.body).size

    assert_equal queries_for_three, queries_for_four,
      "expected a flat query count regardless of loan count (N+1 in serialize_summary)"
  end

  private

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || /^(BEGIN|COMMIT)/.match?(payload[:sql]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
