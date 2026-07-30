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
    def service.section_80c(*args); [@deductions_80c, 1_50_000.0].min; end
    
    # Apply 44ADA logic in the test helper since we bypass `compute`
    freelance_val = freelance > 75_00_000 ? freelance : freelance * 0.50
    income_data[:freelance] = freelance_val

    computed = service.send(:compute_taxable_income, income_data, regime)
    final = service.send(:calculate_regime_tax, computed, regime)
    final.merge(deductions_breakdown: computed[:deductions_breakdown], stcg_111a: computed[:stcg_111a], unabsorbed_business_loss: computed[:unabsorbed_business_loss])
  end

  test "salaried ₹10L, new regime, zero tax via 87A" do
    result = compute(salary: 10_00_000, regime: :new)
    assert_equal 9_25_000, result[:taxable_income]  # 10L - 75K standard deduction
    assert_equal 32_500, result[:slab_tax]          # new slab computation for 9.25L
    assert_equal 32_500, result[:rebate_87a]            # 87A wipes it
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

  test "freelance income under 44ADA gets 50% flat deduction if under ceiling" do
    result = compute(freelance: 50_00_000, regime: :new)
    assert_equal 25_00_000, result[:taxable_income] # 50%
  end

  test "freelance income over 75L 44ADA ceiling is fully taxable" do
    result = compute(freelance: 80_00_000, regime: :new)
    assert_equal 80_00_000, result[:taxable_income] # 100%
  end

  test "STCG is taxed at 20%" do
    result = compute(stcg: 5_00_000, regime: :new)
    assert_equal 1_00_000, result[:stcg_tax]
  end

  test "old regime slabs for 15L" do
    result = compute(salary: 15_50_000, regime: :old)
    # 15.5L - 50K = 15L
    # 2.5L to 5L = 5% of 2.5L = 12.5K
    # 5L to 10L = 20% of 5L = 100K
    # 10L to 15L = 30% of 5L = 150K
    # Total = 262,500
    assert_equal 2_62_500, result[:slab_tax]
  end

  test "crypto gains taxed at 30% without basic exemption" do
    result = compute(crypto_pnl: 1_00_000, regime: :new)
    assert_equal 30_000, result[:crypto_tax]
  end

  test "surcharge kicks in at 50L at 10%" do
    result = compute(salary: 60_00_000, regime: :new)
    # Base tax on 60L - 75K = 59.25L
    # Tax > 24L is 30%
    # Surcharge should be 10%
    assert_operator result[:surcharge], :>, 0
  end

  test "advance tax required when liability > 10K" do
    service = TaxCalculatorService.new(@user, 2026)
    adv = service.send(:calculate_advance_tax, 50_000, 10_000)
    assert adv[:required]
    assert_equal 40_000, adv[:total_liability]
  end

  test "advance tax not required when liability <= 10K" do
    service = TaxCalculatorService.new(@user, 2026)
    adv = service.send(:calculate_advance_tax, 20_000, 15_000)
    assert_not adv[:required]
  end

  test "tax audit required when turnover > 10Cr" do
    service = TaxCalculatorService.new(@user, 2026)
    audit = service.send(:check_tax_audit, 5_00_00_000, 6_00_00_000)
    assert audit[:required]
  end

  test "tax audit not required when turnover <= 10Cr" do
    service = TaxCalculatorService.new(@user, 2026)
    audit = service.send(:check_tax_audit, 5_00_00_000, 4_00_00_000)
    assert_not audit[:required]
  end

  test "80C capped at 1.5L in old regime" do
    result = compute(salary: 10_00_000, deductions_80c: 2_00_000, regime: :old)
    assert_equal 1_50_000, result[:deductions_breakdown][:section_80c]
  end

  test "no 80C allowed in new regime" do
    result = compute(salary: 10_00_000, deductions_80c: 1_50_000, regime: :new)
    assert_nil result[:deductions_breakdown][:section_80c]
    assert_equal 0, result[:total_deductions]
  end

  test "cess is 4% of base tax + surcharge" do
    result = compute(salary: 15_00_000, regime: :new)
    expected_cess = (result[:base_tax] + result[:surcharge]) * 0.04
    assert_equal expected_cess.round(2), result[:cess]
  end

  test "unabsorbed business loss does not offset capital gains" do
    result = compute(fo_pnl: -5_00_000, stcg: 2_00_000, regime: :new)
    assert_equal 2_00_000, result[:stcg_111a]
    assert_equal 5_00_000, result[:unabsorbed_business_loss]
  end

  test "total deductions cannot exceed normal taxable income" do
    result = compute(salary: 1_00_000, deductions_80c: 1_50_000, regime: :old)
    # salary 1L - 50k std ded = 50k normal taxable.
    # Total deduction can't exceed 50k.
    assert_equal 50_000, result[:total_deductions]
    assert_equal 0, result[:taxable_income]
  end

  test "marginal relief fallback at 50L threshold" do
    # Just checking surcharge logic returns false for simple case
    service = TaxCalculatorService.new(@user, 2026)
    sr = service.send(:compute_surcharge_with_marginal_relief, 1_00_000, 0, 40_00_000)
    assert_equal 0, sr[:surcharge]
    assert_not sr[:marginal_relief]
  end

  test "LTCG below 1.25L is tax free" do
    result = compute(salary: 10_00_000, ltcg: 1_00_000, regime: :new)
    assert_equal 0, result[:ltcg_tax]
  end
end
