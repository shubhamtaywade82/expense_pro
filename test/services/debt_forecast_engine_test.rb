require "test_helper"

class DebtForecastEngineTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Forecast User",
      email: "forecast@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "projects the settlement month for a single case" do
    create_case(name: "IDFC", balance: 45_000, obligation: 5_000)

    result = DebtForecastEngine.new(@user, monthly_allocation: 10_000).call

    assert_equal 1, result.settlements.size
    assert_equal 5, result.settlements.first[:month_number] # 45,000 / 10,000
    assert_equal Date.current.advance(months: 5), result.debt_free_on
    assert_equal 45_000.0, result.total_settlement_cost
  end

  test "released cashflow accelerates later settlements" do
    create_case(name: "Branch", balance: 10_000, obligation: 5_000)
    create_case(name: "IDFC", balance: 25_000, obligation: 0)

    result = DebtForecastEngine.new(@user, monthly_allocation: 5_000).call

    branch = result.settlements.find { |s| s[:name] == "Branch" }
    idfc = result.settlements.find { |s| s[:name] == "IDFC" }

    assert_equal 2, branch[:month_number]      # 10,000 by month 2
    # After Branch settles, allocation becomes 10,000/month:
    # month 2 ends with 0, months 3-5 add 30,000, month 5 covers 25,000.
    assert_equal 5, idfc[:month_number]
  end

  test "start fund from contributions is respected" do
    settlement_case = create_case(name: "IDFC", balance: 45_000, obligation: 0)
    settlement_case.settlement_contributions.create!(
      user: @user, amount: 25_000, contributed_on: Date.current
    )

    result = DebtForecastEngine.new(@user, monthly_allocation: 10_000).call

    assert_equal 25_000.0, result.start_fund
    assert_equal 2, result.settlements.first[:month_number] # 25k + 2x10k >= 45k
  end

  test "scenario comparison returns the standard ladder when no income scenarios exist" do
    create_case(name: "IDFC", balance: 45_000, obligation: 0)

    scenarios = DebtForecastEngine.new(@user).scenarios

    assert_equal 4, scenarios.size
    assert_equal [10_000.0, 15_000.0, 30_000.0, 40_000.0], scenarios.map { |s| s[:monthly_allocation] }
    assert scenarios.first[:result].settlements.size == 1
    assert_equal 5, scenarios.first[:result].settlements.first[:month_number]
    assert_equal 2, scenarios.third[:result].settlements.first[:month_number] # 30k/month
  end

  test "uses saved income scenario allocations when present" do
    create_case(name: "IDFC", balance: 45_000, obligation: 0)
    @user.income_scenarios.create!(
      name: "Appraisal", scenario_type: :appraisal, effective_on: Date.current,
      monthly_income_paise: 17_000_000, monthly_commitments_paise: 13_000_000,
      settlement_allocation_paise: 3_500_000 # ₹35,000
    )

    scenarios = DebtForecastEngine.new(@user).scenarios

    assert_equal ["Appraisal"], scenarios.map { |s| s[:label] }
    assert_equal 3_500_000.0 / 100, scenarios.first[:monthly_allocation]
    assert_equal 2, scenarios.first[:result].settlements.first[:month_number]
  end

  test "unaffordable pipeline does not loop forever" do
    create_case(name: "Huge", balance: 10_00_000, obligation: 0) # ₹10,00,000

    result = DebtForecastEngine.new(@user, monthly_allocation: 1_000).call

    assert_empty result.settlements
    assert_nil result.debt_free_on
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
