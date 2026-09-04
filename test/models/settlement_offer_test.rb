require "test_helper"

class SettlementOfferTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Offer User",
      email: "offer@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    account = @user.debt_accounts.create!(
      name: "IDFC PL", lender: "IDFC First Bank",
      debt_type: :personal_loan, classification: :settlement,
      status: :current,
      original_principal_paise: 6_488_800,
      current_balance_paise: 6_488_800
    )

    @case = @user.settlement_cases.create!(
      debt_account: account,
      started_on: Date.current,
      original_claim_paise: 6_488_800,
      current_claim_paise: 6_488_800,
      service_fee_percentage: 15.0,
      gst_percentage: 18.0
    )
  end

  test "offer amounts are recomputed from claim, percentage and case terms" do
    offer = SettlementOffer.create!(
      settlement_case: @case,
      claim_amount_paise: 10_000_000,
      settlement_percentage: 45,
      offered_on: Date.current
    )

    assert_equal 4_500_000, offer.settlement_amount_paise
    assert_equal 1_500_000, offer.service_fee_paise
    assert_equal 270_000, offer.gst_paise
    assert_equal 6_270_000, offer.total_amount_paise
  end

  test "changing the percentage recomputes the breakdown" do
    offer = SettlementOffer.create!(
      settlement_case: @case,
      claim_amount_paise: 10_000_000,
      settlement_percentage: 20,
      offered_on: Date.current
    )

    offer.update!(settlement_percentage: 30)

    assert_equal 3_000_000, offer.settlement_amount_paise
    assert_equal 4_770_000, offer.total_amount_paise
  end

  test "accept! stamps status and date" do
    offer = SettlementOffer.create!(
      settlement_case: @case,
      claim_amount_paise: 10_000_000,
      settlement_percentage: 25,
      offered_on: Date.current
    )

    offer.accept!

    assert_equal "accepted", offer.status
    assert_equal Date.current, offer.accepted_on
  end

  test "expired offers are detected" do
    live = SettlementOffer.create!(
      settlement_case: @case, claim_amount_paise: 10_000_000,
      settlement_percentage: 25, offered_on: Date.current, valid_until: Date.current + 7
    )
    stale = SettlementOffer.create!(
      settlement_case: @case, claim_amount_paise: 10_000_000,
      settlement_percentage: 25, offered_on: Date.current - 30, valid_until: Date.current - 1
    )

    assert_not live.expired?
    assert stale.expired?
  end

  test "money objects are exposed through monetize" do
    offer = SettlementOffer.create!(
      settlement_case: @case,
      claim_amount_paise: 10_000_000,
      settlement_percentage: 45,
      offered_on: Date.current
    )

    assert_instance_of Money, offer.claim_amount
    assert_equal "INR", offer.total_amount.currency.iso_code
    assert_equal 62_700, offer.total_amount.to_f
  end
end
