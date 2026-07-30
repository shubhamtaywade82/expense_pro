require "test_helper"

class IncomeTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Income Tester", email: "income_model@example.com", password: "password123", password_confirmation: "password123")
  end

  test "creates a basic income" do
    income = @user.incomes.create!(source: "Test Income", amount: 50000, income_date: Date.current, is_recurring: false)
    assert income.persisted?
    assert_equal 50000, income.amount
  end

  test "creates a salary income with income_type" do
    income = @user.incomes.create!(source: "Salary", amount: 80000, income_date: Date.current, is_recurring: true, frequency: "monthly", income_type: "salary", gross_amount: 100000, tax_deducted: 10000, pf_deducted: 6000)
    assert income.persisted?
    assert_equal "salary", income.income_type
    assert_equal 100000, income.gross_amount
  end

  test "creates income linked to employment" do
    employment = @user.employments.create!(employer_name: "Test Corp", designation: "Engineer", start_date: Date.current - 1.year, is_current: true, monthly_ctc: 1200000)
    income = @user.incomes.create!(source: "Test Corp Salary", amount: 100000, income_date: Date.current, is_recurring: true, frequency: "monthly", employment: employment)
    assert_equal employment.id, income.employment_id
  end

  test "income_type defaults to salary per schema" do
    income = @user.incomes.create!(source: "Cash", amount: 1000, income_date: Date.current, is_recurring: false)
    assert_equal "salary", income.income_type
  end
end
