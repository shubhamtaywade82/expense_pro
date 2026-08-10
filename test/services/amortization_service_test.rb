require "test_helper"

class AmortizationServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Loan Tester", email: "loan_tester_#{SecureRandom.hex(4)}@example.com", password: "password123")
    @loan = LoanAccount.create!(
      user: @user,
      name: "Tata Capital Home Loan",
      lender: "Tata Capital",
      loan_type: "home_loan",
      principal_amount: 4600000,
      interest_rate: 8.60,
      tenure_months: 240,
      start_date: Date.new(2023, 2, 28),
      status: "active"
    )
  end

  test "generates standard amortization schedule" do
    service = AmortizationService.new(@loan)
    service.generate_schedule!

    assert_equal 240, @loan.emi_schedules.count
    first_emi = @loan.emi_schedules.first
    assert_equal 1, first_emi.installment_number
    assert first_emi.emi_amount > 30000
    assert first_emi.interest_component > 0
    assert first_emi.principal_component > 0
  end

  test "recalculates multistage schedule with floating rate history while preserving paid statuses" do
    service = AmortizationService.new(@loan)
    service.generate_schedule!

    # Mark first 3 EMIs as paid
    @loan.emi_schedules.where(installment_number: 1..3).update_all(status: "paid", paid_on: Date.today)

    rate_revisions = [
      { effective_date: "2023-02-28", interest_rate: 8.60, strategy: "adjust_tenure" },
      { effective_date: "2023-08-01", interest_rate: 8.85, strategy: "adjust_tenure" },
      { effective_date: "2024-02-01", interest_rate: 9.15, strategy: "adjust_tenure" },
      { effective_date: "2025-01-01", interest_rate: 8.60, strategy: "adjust_tenure" },
      { effective_date: "2025-06-01", interest_rate: 8.15, strategy: "adjust_tenure" }
    ]

    service.recalculate_multistage!(rate_revisions: rate_revisions)

    assert_equal 3, @loan.emi_schedules.where(status: "paid").count
    assert @loan.emi_schedules.count > 100
  end

  test "supports importing custom schedule rows" do
    service = AmortizationService.new(@loan)
    rows = [
      { installment_number: 1, due_date: "2023-03-28", emi_amount: 40000, principal_component: 10000, interest_component: 30000, opening_balance: 4600000, closing_balance: 4590000, status: "paid" },
      { installment_number: 2, due_date: "2023-04-28", emi_amount: 40000, principal_component: 10100, interest_component: 29900, opening_balance: 4590000, closing_balance: 4579900, status: "paid" }
    ]

    service.import_schedule!(rows)
    assert_equal 2, @loan.emi_schedules.count
    assert_equal 2, @loan.emi_schedules.where(status: "paid").count
    assert_equal 4579900, @loan.reload.outstanding_principal
  end

  test "updates individual installment" do
    service = AmortizationService.new(@loan)
    service.generate_schedule!

    first_emi = @loan.emi_schedules.first
    updated = service.update_installment!(first_emi.id, { emi_amount: 42000, status: "paid", paid_on: Date.today })

    assert_equal 42000, updated.emi_amount
    assert_equal "paid", updated.status
  end
end
