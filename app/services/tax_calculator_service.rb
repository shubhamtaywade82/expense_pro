class TaxCalculatorService
  CACHE_TTL = 1.hour

  def initialize(user, financial_year = nil)
    @user = user
    @year = financial_year || default_financial_year
  end

  def call
    Rails.cache.fetch("itr:#{@user.id}:#{@year}", expires_in: CACHE_TTL) do
      compute
    end
  end

  private

  def compute
    start_d = Date.new(@year - 1, 4, 1)
    end_d = Date.new(@year, 3, 31)

    incomes = IncomeProjectionService.new(@user, start_d, end_d).call

    salary_incomes = incomes.select { |i| %w[salary bonus fnf].include?(i.income_type) || i.income_type.blank? }
    gross_salary = salary_incomes.sum { |inc| (inc.gross_amount || inc.amount).to_f }

    freelance_incomes = incomes.select { |i| i.income_type == "freelance" }
    gross_freelance = freelance_incomes.sum { |inc| (inc.gross_amount || inc.amount).to_f }
    taxable_freelance = gross_freelance * 0.50

    tds_from_incomes = incomes.sum { |inc| inc.tax_deducted.to_f }
    tds_from_deductions = TaxDeduction.for_fy(@year).sum(:tds_amount).to_f
    tds_paid = tds_from_incomes + tds_from_deductions

    # Investments
    investments = @user.investments
      .where(purchase_date: start_d..end_d)
      .or(@user.investments.where(status: "realized", sell_date: start_d..end_d))

    speculative_pnl = investments.select { |i| i.asset_class == "speculative_intraday" }.sum(&:total_pnl).to_f
    non_speculative_fo_pnl = investments.select { |i| i.asset_class == "non_speculative_fo" }.sum(&:total_pnl).to_f
    crypto_pnl = investments.select { |i| i.asset_class == "crypto" }.sum(&:total_pnl).to_f
    fixed_income_pnl = investments.select { |i| i.asset_class == "fixed_income" }.sum(&:total_pnl).to_f

    gold_investments = investments.select { |i| i.asset_class == "gold" }
    gold_stcg = gold_investments.select { |i| (i.sell_date || Date.current) - i.purchase_date < 1095 }.sum(&:total_pnl).to_f
    gold_ltcg = gold_investments.select { |i| (i.sell_date || Date.current) - i.purchase_date >= 1095 }.sum(&:total_pnl).to_f

    stcg_investments = investments.select(&:stcg?)
    ltcg_investments = investments.select(&:ltcg?)
    stcg_pnl = stcg_investments.sum(&:total_pnl).to_f
    ltcg_pnl = ltcg_investments.sum(&:total_pnl).to_f

    # Deductions
    elss_amount = investments.select { |i| i.asset_class == "elss_80c" }.sum(&:invested_amount).to_f
    home_loans = @user.loans.where(loan_type: "home")

    home_loan_principal = home_loans.sum { |l| home_loan_paid_principal(l, start_d, end_d) }
    sec_80c = [elss_amount + home_loan_principal, 150_000.0].min

    home_loan_interest = home_loans.sum { |l| home_loan_paid_interest(l, start_d, end_d) }
    sec_24b_old = [home_loan_interest, 200_000.0].min

    # HRA exemption (Old Regime only) — aggregate across current employments with HRA
    hra_exempt = compute_hra_exemption(start_d, end_d)

    # 80D Health Insurance
    health_category_ids = @user.categories.where(name: "Health", category_type: "expense").pluck(:id)
    sec_80d = if health_category_ids.any?
      total = @user.expenses.where(category_id: health_category_ids, expense_date: start_d..end_d).sum(:amount).to_f
      [total, 25_000.0].min
    else
      0.0
    end

    # 80CCD(1B) NPS (separate from 80C)
    sec_80ccd_1b = [investments.select { |i| i.asset_class == "nps" }.sum(&:invested_amount).to_f, 50_000.0].min

    # 80TTA Savings Interest Deduction
    sec_80tta = 10_000.0

    # Standard Deductions
    std_deduction_new = 75_000.0
    std_deduction_old = 50_000.0

    # Taxable Income
    # New Regime: Salary - 75K + Freelance + F&O + Speculative + Fixed Income
    taxable_new = [gross_salary - std_deduction_new, 0].max +
      taxable_freelance + non_speculative_fo_pnl + [speculative_pnl, 0].max + [fixed_income_pnl, 0].max

    # Old Regime: Salary - 50K - 80C - 24B - HRA + Freelance + F&O + Speculative + Fixed Income
    taxable_old = [gross_salary - std_deduction_old - sec_80c - sec_24b_old - hra_exempt, 0].max +
      taxable_freelance + non_speculative_fo_pnl + [speculative_pnl, 0].max + [fixed_income_pnl, 0].max

    tax_new = calculate_new_regime_tax(taxable_new)
    tax_old = calculate_old_regime_tax(taxable_old)

    # Special taxes (same for both regimes)
    stcg_tax = stcg_pnl > 0 ? (stcg_pnl * 0.20).round(2) : 0.0
    taxable_ltcg = [ltcg_pnl - 125_000.0, 0].max
    ltcg_tax = taxable_ltcg > 0 ? (taxable_ltcg * 0.125).round(2) : 0.0
    gold_ltcg_tax = gold_ltcg > 0 ? (gold_ltcg * 0.20).round(2) : 0.0
    crypto_tax = crypto_pnl > 0 ? (crypto_pnl * 0.30).round(2) : 0.0

    total_tax_new = (tax_new[:total_tax] + stcg_tax + ltcg_tax + gold_ltcg_tax + crypto_tax).round(2)
    total_tax_old = (tax_old[:total_tax] + stcg_tax + ltcg_tax + gold_ltcg_tax + crypto_tax).round(2)

    tax_payable_new = [total_tax_new - tds_paid, 0].max.round(2)
    tax_payable_old = [total_tax_old - tds_paid, 0].max.round(2)

    recommended_regime = total_tax_new <= total_tax_old ? "New Tax Regime" : "Old Tax Regime"
    tax_saved = (total_tax_old - total_tax_new).abs.round(2)

    recommended_itr = if speculative_pnl != 0 || non_speculative_fo_pnl != 0 || gross_freelance > 0 || fixed_income_pnl != 0
                        "ITR-3 / ITR-4 (Business & Professional Income)"
    elsif stcg_pnl != 0 || ltcg_pnl != 0 || crypto_pnl != 0 || gold_stcg != 0 || gold_ltcg != 0
                        "ITR-2 (Capital Gains & Crypto Income)"
    else
                        "ITR-1 (Sahaj - Salary & Interest Income)"
    end

    {
      financial_year: "FY #{@year - 1}-#{String(@year)[2..3]}",
      assessment_year: "AY #{@year}-#{String(@year + 1)[2..3]}",
      gross_salary: gross_salary,
      gross_freelance: gross_freelance,
      tds_already_paid: tds_paid,
      trading_summary: {
        speculative_intraday_pnl: speculative_pnl,
        non_speculative_fo_pnl: non_speculative_fo_pnl,
        crypto_pnl: crypto_pnl,
        fixed_income_pnl: fixed_income_pnl,
        gold_stcg_pnl: gold_stcg,
        gold_ltcg_pnl: gold_ltcg,
        stcg_pnl: stcg_pnl,
        ltcg_pnl: ltcg_pnl,
        total_pnl: speculative_pnl + non_speculative_fo_pnl + crypto_pnl + fixed_income_pnl + gold_stcg + gold_ltcg + stcg_pnl + ltcg_pnl
      },
      deductions: {
        section_80c: sec_80c.round(2),
        section_24b_home_loan_interest: sec_24b_old.round(2),
        hra_exemption: hra_exempt.round(2),
        section_80d: sec_80d.round(2),
        section_80ccd_1b: sec_80ccd_1b.round(2),
        section_80tta: sec_80tta,
        standard_deduction_new: std_deduction_new,
        standard_deduction_old: std_deduction_old
      },
      new_regime: {
        taxable_income: taxable_new.round(2),
        slab_tax: tax_new[:slab_tax],
        rebate_87a: tax_new[:rebate],
        surcharge: tax_new[:surcharge],
        cess: tax_new[:cess],
        total_tax: total_tax_new
      },
      old_regime: {
        taxable_income: taxable_old.round(2),
        slab_tax: tax_old[:slab_tax],
        rebate_87a: tax_old[:rebate],
        surcharge: tax_old[:surcharge],
        cess: tax_old[:cess],
        total_tax: total_tax_old
      },
      special_taxes: {
        stcg_tax_sec111a: stcg_tax,
        ltcg_tax_sec112a: ltcg_tax,
        gold_ltcg_tax_sec112: gold_ltcg_tax,
        crypto_tax_sec115bbh: crypto_tax
      },
      advance_tax: calculate_advance_tax(total_tax_new, tds_paid),
      tax_audit: check_tax_audit(speculative_pnl, non_speculative_fo_pnl),
      recommendation: {
        best_regime: recommended_regime,
        tax_saved: tax_saved,
        itr_form: recommended_itr
      }
    }
  end

  def calculate_advance_tax(total_tax, tds_paid)
    net_payable = [total_tax - tds_paid, 0].max
    return { required: false, message: "Net tax payable below threshold" } if net_payable <= 10_000

    installments = [
      { due_month: "June 15", percentage: 15, amount: (net_payable * 0.15).round(0) },
      { due_month: "September 15", percentage: 45, amount: (net_payable * 0.45).round(0) },
      { due_month: "December 15", percentage: 75, amount: (net_payable * 0.75).round(0) },
      { due_month: "March 15", percentage: 100, amount: net_payable.round(0) }
    ]

    {
      required: true,
      total_liability: net_payable.round(0),
      installments: installments,
      interest_234b: "1% per month for delay in paying advance tax (simple interest)",
      interest_234c: "1% per month on shortfall in each installment"
    }
  end

  def check_tax_audit(speculative, non_speculative)
    turnover = speculative.abs + non_speculative.abs
    return { required: false } if turnover <= 10_00_00_000

    {
      required: true,
      turnover: turnover.round(2),
      threshold: "₹10 Crore",
      section: "44AB",
      due_date: "#{@year}-09-30",
      penalty: "0.5% of turnover or ₹1,50,000 whichever lower"
    }
  end

  def calculate_new_regime_tax(income)
    return { slab_tax: 0.0, rebate: 0.0, surcharge: 0.0, cess: 0.0, total_tax: 0.0 } if income <= 400_000

    tax = 0.0
    tax += (800_000 - 400_000) * 0.05 if income > 400_000
    tax += ([income, 1_200_000].min - 800_000) * 0.10 if income > 800_000
    tax += ([income, 1_600_000].min - 1_200_000) * 0.15 if income > 1_200_000
    tax += ([income, 2_000_000].min - 1_600_000) * 0.20 if income > 1_600_000
    tax += ([income, 2_400_000].min - 2_000_000) * 0.25 if income > 2_000_000
    tax += (income - 2_400_000) * 0.30 if income > 2_400_000

    # 87A rebate with marginal relief (New Regime, threshold 12L)
    if income <= 1_200_000
      return { slab_tax: tax.round(2), rebate: tax.round(2), surcharge: 0.0, cess: 0.0, total_tax: 0.0 }
    end

    rebate_amount = marginal_relief(tax, income, 1_200_000)
    tax_after_rebate = [tax - rebate_amount, 0].max

    surcharge = compute_surcharge(tax_after_rebate, income)
    cess = ((tax_after_rebate + surcharge) * 0.04).round(2)
    total_tax = (tax_after_rebate + surcharge + cess).round(2)

    { slab_tax: tax.round(2), rebate: rebate_amount.round(2), surcharge: surcharge.round(2), cess: cess.round(2), total_tax: total_tax }
  end

  def calculate_old_regime_tax(income)
    return { slab_tax: 0.0, rebate: 0.0, surcharge: 0.0, cess: 0.0, total_tax: 0.0 } if income <= 250_000

    tax = 0.0
    tax += ([income, 500_000].min - 250_000) * 0.05 if income > 250_000
    tax += ([income, 1_000_000].min - 500_000) * 0.20 if income > 500_000
    tax += (income - 1_000_000) * 0.30 if income > 1_000_000

    # 87A rebate with marginal relief (Old Regime, threshold 5L)
    if income <= 500_000
      return { slab_tax: tax.round(2), rebate: tax.round(2), surcharge: 0.0, cess: 0.0, total_tax: 0.0 }
    end

    rebate_amount = marginal_relief(tax, income, 500_000)
    tax_after_rebate = [tax - rebate_amount, 0].max

    surcharge = compute_surcharge(tax_after_rebate, income)
    cess = ((tax_after_rebate + surcharge) * 0.04).round(2)
    total_tax = (tax_after_rebate + surcharge + cess).round(2)

    { slab_tax: tax.round(2), rebate: rebate_amount.round(2), surcharge: surcharge.round(2), cess: cess.round(2), total_tax: total_tax }
  end

  def compute_surcharge(tax, income)
    return 0.0 if income <= 5_000_000

    rate = if income > 50_000_000
      0.37
    elsif income > 20_000_000
      0.25
    elsif income > 10_000_000
      0.15
    elsif income > 5_000_000
      0.10
    else
      0.0
    end
    (tax * rate).round(2)
  end

  def marginal_relief(tax, income, threshold)
    return 0.0 if income <= threshold

    excess = income - threshold
    if tax > excess
      (tax - excess).round(2)
    else
      0.0
    end
  end

  def home_loan_paid_principal(loan, start_d, end_d)
    loan.emi_payments.where(is_paid: true, due_date: start_d..end_d).sum(:principal_amount).to_f
  end

  def home_loan_paid_interest(loan, start_d, end_d)
    loan.emi_payments.where(is_paid: true, due_date: start_d..end_d).sum(:interest_amount).to_f
  end

  def compute_hra_exemption(start_d, end_d)
    total = 0.0

    active_employments = @user.employments.select do |e|
      e_start = e.start_date
      e_end = e.end_date || Date.current
      e_start <= end_d && e_end >= start_d
    end

    active_employments.each do |employment|
      result = HraExemptionService.new(employment).call
      total += result[:hra_exempt].to_f
    end

    total
  end

  def default_financial_year
    today = Date.current
    today.month >= 4 ? today.year : today.year - 1
  end
end
