require "test_helper"

class SettlementPaymentServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Payment User",
      email: "payment@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    account = @user.debt_accounts.create!(
      name: "L&T", lender: "L&T Finance",
      debt_type: :personal_loan, classification: :settlement,
      status: :overdue,
      original_principal_paise: 8_000_000,
      current_balance_paise: 8_000_000,
      monthly_obligation_paise: 3_000_000
    )

    @case = @user.settlement_cases.create!(
      debt_account: account,
      started_on: Date.current,
      original_claim_paise: 8_000_000,
      current_claim_paise: 8_000_000,
      status: :agreed
    )

    @offer = SettlementOffer.create!(
      settlement_case: @case,
      claim_amount_paise: 8_000_000,
      settlement_percentage: 40,
      offered_on: Date.current,
      valid_until: Date.current + 10
    )
  end

  test "recording a payment closes the loop end to end" do
    # 40% of ₹80,000 = ₹32,000; fee 15% = ₹12,000; GST 18% = ₹2,160.
    result = SettlementPaymentService.record(
      user: @user,
      settlement_case: @case,
      settlement_offer: @offer,
      reference_number: "NEFT-123",
      sync_to_expenses: true
    )

    assert result[:success]

    payment = result[:payment]
    assert_equal 3_200_000, payment.settlement_amount_paise
    assert_equal 1_200_000, payment.service_fee_paise
    assert_equal 216_000, payment.gst_paise
    assert_equal 4_616_000, payment.total_paid_paise

    # Offer accepted, case settled, debt zeroed.
    assert_equal "accepted", @offer.reload.status
    assert_equal "settled", @case.reload.status
    assert_predicate @case.closed_on, :present?
    assert_equal "settled", @case.debt_account.reload.status
    assert_equal 0, @case.debt_account.current_balance_paise

    # Expense ledger got one classified entry with the full outflow.
    assert payment.synced_to_expenses
    expense = Expense.order(:id).last
    assert_equal "Debt Settlement", expense.category.name
    assert_equal 46_160.0, expense.amount.to_f
    assert_match(/L&T/, expense.description)
  end

  test "recording without an offer falls back to the case's worst-case terms" do
    result = SettlementPaymentService.record(
      user: @user,
      settlement_case: @case,
      settlement_offer: nil,
      sync_to_expenses: false
    )

    assert result[:success]
    # 80,000 @ 45% = 36,000; fee 12,000; GST 2,160 -> 50,160.
    assert_equal 5_016_000, result[:payment].total_paid_paise
  end

  test "no expense is created when sync is disabled" do
    assert_no_difference "Expense.count" do
      SettlementPaymentService.record(
        user: @user, settlement_case: @case, settlement_offer: @offer, sync_to_expenses: false
      )
    end
  end
end
