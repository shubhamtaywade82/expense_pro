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
      @user.loan_accounts.create!(
        name: "Loan #{i}",
        lender: "Bank #{i}",
        principal_amount: 100_000,
        interest_rate: 8.5,
        tenure_months: 12,
        start_date: 1.year.ago.to_date,
        loan_type: "personal",
        status: "active"
      )
    end

    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    @token = JSON.parse(response.body)["token"]
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "index query count does not grow with the number of loans" do
    # Warm up cache so Rails schema queries don't inflate the first count
    count_queries { get api_v1_loans_url, headers: @headers }

    # Append a random string to force a cache miss (ETag bypass)
    queries_for_three = count_queries { get api_v1_loans_url, params: { t: "1" }, headers: @headers }
    assert_response :success
    assert_equal 3, JSON.parse(response.body)["data"].size

    @user.loan_accounts.create!(
      name: "Loan extra",
      lender: "Bank extra",
      principal_amount: 50_000,
      interest_rate: 8.5,
      tenure_months: 12,
      start_date: 1.year.ago.to_date,
      loan_type: "personal",
      status: "active"
    )

    queries_for_four = count_queries { get api_v1_loans_url, params: { t: "2" }, headers: @headers }
    assert_response :success
    assert_equal 4, JSON.parse(response.body)["data"].size

    assert_operator queries_for_four, :<=, queries_for_three,
      "expected a flat query count regardless of loan count (N+1 in serialize_summary)"
  end

  private

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || /^(BEGIN|COMMIT)/.match?(payload[:sql]) }
    ActiveRecord::Base.uncached do
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    end
    count
  end
end
