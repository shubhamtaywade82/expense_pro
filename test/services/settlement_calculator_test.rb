require "test_helper"

class SettlementCalculatorTest < ActiveSupport::TestCase
  test "Freed formula: claim 1,00,000 at 45 percent with 15 percent fee and 18 percent GST" do
    result = SettlementCalculator.call(
      claim_paise: 10_000_000, # ₹1,00,000.00
      settlement_percentage: 45,
      service_fee_percentage: 15.0,
      gst_percentage: 18.0
    )

    assert_equal 10_000_000, result[:claim_paise]
    assert_equal 4_500_000, result[:settlement_amount_paise] # ₹45,000
    assert_equal 1_500_000, result[:service_fee_paise]        # ₹15,000
    assert_equal 270_000, result[:gst_paise]                  # ₹2,700
    assert_equal 6_270_000, result[:total_paise]              # ₹62,700
  end

  test "service fee is charged on the claim, not the settlement amount" do
    # At 20 percent the fee stays 15,000 (15 percent of the claim).
    result = SettlementCalculator.call(
      claim_paise: 10_000_000,
      settlement_percentage: 20,
      service_fee_percentage: 15.0,
      gst_percentage: 18.0
    )

    assert_equal 2_000_000, result[:settlement_amount_paise] # ₹20,000
    assert_equal 1_500_000, result[:service_fee_paise]       # ₹15,000
    assert_equal 270_000, result[:gst_paise]                 # ₹2,700
    assert_equal 3_770_000, result[:total_paise]             # ₹37,700
  end

  test "scenario ladder matches the comparison table" do
    scenarios = SettlementCalculator.scenarios(claim_paise: 10_000_000)

    assert_equal SettlementCalculator::DEFAULT_PERCENTAGES, scenarios.map { |s| s[:settlement_percentage].to_i }
    assert_equal [3_770_000, 4_270_000, 4_770_000, 5_270_000, 5_770_000, 6_270_000],
                 scenarios.map { |s| s[:total_paise] }
  end

  test "amounts round half-up to the paisa" do
    # IDFC notice: claim ₹64,888 at 30 percent.
    result = SettlementCalculator.call(
      claim_paise: 6_488_800,
      settlement_percentage: 30,
      service_fee_percentage: 15.0,
      gst_percentage: 18.0
    )

    assert_equal 1_946_640, result[:settlement_amount_paise] # ₹19,466.40 exact
    assert_equal 973_320, result[:service_fee_paise]         # ₹9,733.20 exact
    assert_equal 175_198, result[:gst_paise]                 # 175197.6 paise rounds half-up
    assert_equal 3_095_158, result[:total_paise]
  end

  test "zero claim produces zero cost" do
    result = SettlementCalculator.call(claim_paise: 0, settlement_percentage: 45)

    assert_equal 0, result[:total_paise]
  end
end
