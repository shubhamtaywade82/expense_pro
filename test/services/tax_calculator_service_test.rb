require "test_helper"

class TaxCalculatorServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Tax Test User",
      email: "tax_calc_test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "only counts a realized investment in the financial year it was actually sold" do
    # Sold in FY 2025-26 (1 Apr 2025 - 31 Mar 2026)
    @user.investments.create!(
      name: "Sold this year",
      asset_class: "non_speculative_fo",
      quantity: 1,
      buy_price: 1000,
      sell_price: 1500,
      purchase_date: Date.new(2025, 5, 1),
      sell_date: Date.new(2025, 6, 1),
      status: "realized"
    )

    # Sold in an earlier FY — must NOT leak into FY 2025-26's total
    @user.investments.create!(
      name: "Sold two years ago",
      asset_class: "non_speculative_fo",
      quantity: 1,
      buy_price: 1000,
      sell_price: 2000,
      purchase_date: Date.new(2023, 5, 1),
      sell_date: Date.new(2023, 6, 1),
      status: "realized"
    )

    result = TaxCalculatorService.new(@user, 2026).call

    assert_equal 500.0, result[:trading_summary][:non_speculative_fo_pnl]
  end

  test "includes an active position in the FY it was purchased" do
    @user.investments.create!(
      name: "Still open",
      asset_class: "speculative_intraday",
      quantity: 1,
      buy_price: 1000,
      current_price: 1200,
      purchase_date: Date.new(2025, 5, 1),
      status: "active"
    )

    result = TaxCalculatorService.new(@user, 2026).call

    assert_equal 200.0, result[:trading_summary][:speculative_intraday_pnl]
  end
end
