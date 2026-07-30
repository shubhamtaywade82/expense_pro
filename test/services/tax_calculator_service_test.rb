require "test_helper"

class TaxCalculatorServiceAccuracyTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Tax Tester", email: "tax_tester@example.com", password: "password123")
  end

  def compute(salary: 0, freelance: 0, interest: 0, fo_pnl: 0, stcg: 0, ltcg: 0, crypto_pnl: 0, deductions_80c: 0, regime: :new, home_loan: nil)
    service = TaxCalculatorService.new(@user, 2026)
    
    income_data = {
      gross_salary: salary,
      freelance: freelance,
      interest: interest,
      dividend: 0,
      speculative_pnl: 0,
      non_speculative_fo_pnl: fo_pnl,
      crypto_pnl: crypto_pnl,
      fixed_income_pnl: 0,
      gold_stcg: 0,
      gold_ltcg: 0,
      stcg_pnl: stcg,
      ltcg_pnl: ltcg,
      investments: [],
      start_d: Date.new(2025, 4, 1),
      end_d: Date.new(2026, 3, 31)
    }

    service.instance_variable_set(:@deductions_80c, deductions_80c)
    def service.section_80c(*args); @deductions_80c; end
    
    computed = service.send(:compute_taxable_income, income_data, regime)
    final = service.send(:calculate_regime_tax, computed, regime)
    final.merge(deductions_breakdown: computed[:deductions_breakdown])
  end

  test "salaried ₹10L, new regime, zero tax via 87A" do
    result = compute(salary: 10_00_000, regime: :new)
    assert_equal 9_25_000, result[:taxable_income]  # 10L - 75K standard deduction
    assert_equal 32_500, result[:slab_tax]          # new slab computation for 9.25L
    assert_equal 32_500, result[:rebate]            # 87A wipes it
    assert_equal 0, result[:total_tax]
  end

  test "marginal relief at ₹12,01,000 new regime" do
    result = compute(salary: 12_76_000, regime: :new)  # taxable = 12,01,000
    assert_equal 1040, result[:total_tax]
    assert result[:marginal_relief_applied]
  end

  test "F&O loss sets off against salary" do
    result = compute(salary: 15_00_000, fo_pnl: -5_00_000, regime: :new)
    assert_equal 9_25_000, result[:taxable_income]
    assert_equal 0, result[:unabsorbed_business_loss]
  end

  test "F&O loss exceeding income carries forward" do
    result = compute(salary: 8_00_000, fo_pnl: -12_00_000, regime: :new)
    assert_equal 0, result[:taxable_income]
    assert_equal 4_75_000, result[:unabsorbed_business_loss]
  end

  test "LTCG ₹2L taxed only above ₹1.25L exemption at 12.5%" do
    result = compute(salary: 10_00_000, ltcg: 2_00_000, regime: :new)
    assert_equal 9_375, result[:ltcg_tax]
  end

  test "crypto loss is NOT set off (115BBH)" do
    result = compute(salary: 10_00_000, crypto_pnl: -3_00_000, regime: :new)
    assert_equal 0, result[:crypto_tax]
    assert_equal 10_00_000 - 75_000, result[:taxable_income]
  end

  test "surcharge capped at 15% on capital gains above ₹5Cr" do
    result = compute(salary: 6_00_00_000, ltcg: 1_00_00_000, regime: :new)
    assert_operator result[:surcharge_on_cg], :<=, (result[:ltcg_tax] * 0.15) + 1
  end

  test "home loan 24b uses amortization not linear, self-occupied capped at 2L" do
    category = Category.find_by(name: "Loans") || Category.create!(name: "Loans", category_type: "expense", user: @user)
    loan = @user.loans.create!(
      name: "Home Loan",
      loan_type: "home",
      principal_amount: 50_00_000,
      interest_rate: 8.5,
      tenure_months: 240,
      start_date: Date.new(2025, 4, 1),
      category: category,
      occupancy: "self_occupied"
    )
    result = compute(salary: 20_00_000, home_loan: loan, regime: :old)
    
    assert_equal 2_00_000, result[:deductions_breakdown][:section_24b]
    
    interest = loan.emi_payments.where(due_date: Date.new(2025,4,1)..Date.new(2026,3,31)).sum(:interest_amount)
    assert_operator interest, :>, 3_50_000
  end
end
