require "test_helper"

class Api::V1::BudgetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test User",
      email: "budgets_test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @categories = @user.categories.where(category_type: "expense").limit(3).to_a
    @month = 6
    @year = 2026

    @categories.each do |category|
      @user.budgets.create!(category: category, month: @month, year: @year, amount: 5000, alert_threshold: 80)
      @user.expenses.create!(category: category, amount: 1200, description: "Test spend", expense_date: Date.new(@year, @month, 10))
    end

    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    @token = JSON.parse(response.body)["token"]
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "index reports correct spend per category and does not N+1 per budget" do
    queries_for_three = count_queries { get api_v1_budgets_url, params: { month: @month, year: @year }, headers: @headers }
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 3, body.size
    body.each { |b| assert_equal 1200.0, b["spent"] }

    extra_category = @user.categories.where(category_type: "expense").where.not(id: @categories.map(&:id)).first
    @user.budgets.create!(category: extra_category, month: @month, year: @year, amount: 5000, alert_threshold: 80)
    @user.expenses.create!(category: extra_category, amount: 900, description: "Extra spend", expense_date: Date.new(@year, @month, 12))

    queries_for_four = count_queries { get api_v1_budgets_url, params: { month: @month, year: @year }, headers: @headers }
    assert_response :success
    assert_equal 4, JSON.parse(response.body).size

    assert_equal queries_for_three, queries_for_four,
      "expected a flat query count regardless of budget count (N+1 in Budget#actual_spent)"
  end

  private

  def count_queries(&block)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || /^(BEGIN|COMMIT)/.match?(payload[:sql]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
