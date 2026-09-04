require "test_helper"

class SettlementSimulatorTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Simulator User",
      email: "simulator@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    # Fee/GST zeroed and 100% "settlement" so estimated totals equal the
    # claims — keeps the allocation arithmetic easy to verify by eye.
    @a = create_case(name: "Account A", balance: 18_000, obligation: 4_000)
    @b = create_case(name: "Account B", balance: 27_000, obligation: 6_000)
    @c = create_case(name: "Account C", balance: 32_000, obligation: 8_000)
    @d = create_case(name: "Account D", balance: 50_000, obligation: 10_000)
  end

  test "settles every account the cash can fully fund, cheapest first" do
    result = SettlementSimulator.new(@user).call(available_cash: 1_00_000)

    assert_equal %w[Account A Account B Account C], result[:allocations].map { |a| a[:name] }
    assert_equal 3, result[:accounts_eliminated]
    assert_equal 77_000.0, result[:total_settlement_cost]
    assert_equal 23_000.0, result[:remaining_cash]
    assert_equal 18_000.0 + 27_000.0 + 32_000.0, result[:debt_removed]
  end

  test "reports monthly cashflow recovered by eliminated accounts" do
    result = SettlementSimulator.new(@user).call(available_cash: 1_00_000)

    assert_equal 4_000.0 + 6_000.0 + 8_000.0, result[:monthly_cashflow_recovered]
  end

  test "next target carries the shortfall and months to fund it" do
    # ₹15,000/month settlement allocation via the active income scenario.
    @user.income_scenarios.create!(
      name: "Current", scenario_type: :current, effective_on: Date.current,
      monthly_income_paise: 14_500_000, monthly_commitments_paise: 13_000_000,
      settlement_allocation_paise: 1_500_000, is_active: true
    )

    result = SettlementSimulator.new(@user).call(available_cash: 1_00_000)

    assert_equal "Account D", result[:next_target][:name]
    assert_equal 50_000.0, result[:next_target][:settlement_cost]
    assert_equal 23_000.0, result[:remaining_cash]
    assert_equal 27_000.0, result[:next_target][:shortfall]
    assert_equal 2, result[:next_target][:months_to_fund] # ceil(27,000 / 15,000)
  end

  test "tiny cash settles nothing but still names the next target" do
    result = SettlementSimulator.new(@user).call(available_cash: 5_000)

    assert_equal 0, result[:accounts_eliminated]
    assert_equal "Account A", result[:next_target][:name]
    assert_equal 18_000.0, result[:next_target][:shortfall]
  end

  test "legal opportunities are funded before cheaper small balances" do
    # Account D gets a formal notice: despite being the most expensive,
    # stage 1 comes first when cash covers it.
    @d.debt_account.update!(formal_notice: true)

    result = SettlementSimulator.new(@user).call(available_cash: 50_000)

    assert_equal %w[Account D], result[:allocations].map { |a| a[:name] }
    assert_equal 0.0, result[:remaining_cash]
  end

  private

  def create_case(name:, balance:, obligation:)
    account = @user.debt_accounts.create!(
      name: name,
      lender: name,
      debt_type: :personal_loan,
      classification: :settlement,
      status: :current,
      original_principal_paise: balance * 100,
      current_balance_paise: balance * 100,
      monthly_obligation_paise: obligation * 100
    )

    @user.settlement_cases.create!(
      debt_account: account,
      started_on: Date.current,
      original_claim_paise: balance * 100,
      current_claim_paise: balance * 100,
      target_min_percentage: 100,
      target_max_percentage: 100,
      service_fee_percentage: 0.0,
      gst_percentage: 0.0
    )
  end
end
