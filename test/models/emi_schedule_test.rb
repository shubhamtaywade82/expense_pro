require "test_helper"

class EmiScheduleTest < ActiveSupport::TestCase
  test "for_fy filters due dates in financial year" do
    user = User.create!(name: "Loan User", email: "loan_user@example.com", password: "password123")
    loan = user.loan_accounts.create!(
      name: "Home Loan",
      lender: "HDFC",
      loan_type: "home_loan",
      principal_amount: 5000000,
      outstanding_principal: 4500000,
      interest_rate: 8.5,
      start_date: Date.new(2025, 4, 1),
      tenure_months: 240,
      emi_amount: 43391
    )
    s1 = loan.emi_schedules.create!(due_date: Date.new(2025, 5, 5), installment_number: 1, emi_amount: 43391)
    s2 = loan.emi_schedules.create!(due_date: Date.new(2024, 5, 5), installment_number: 2, emi_amount: 43391)

    assert_includes loan.emi_schedules.for_fy(2026), s1
    assert_not_includes loan.emi_schedules.for_fy(2026), s2
  end
end
