# frozen_string_literal: true

class TaxCalculatorService
  def initialize(user, financial_year = 2026)
    @user = user
    @year = financial_year
  end

  def call
    start_d = Date.new(@year - 1, 4, 1) # e.g. FY 2025-26 start 1 April 2025
    end_d = Date.new(@year, 3, 31)      # e.g. 31 March 2026

    # 1. Salary & Other Incomes
    incomes = IncomeProjectionService.new(@user, start_d, end_d).call
    gross_salary = incomes.sum { |inc| inc.amount.to_f }

    # 2. Investments & Capital Gains breakdown
    investments = @user.investments.where(purchase_date: start_d..end_d).or(@user.investments.realized)

    speculative_pnl = investments.select { |i| i.asset_class == "speculative_intraday" }.sum(&:total_pnl).to_f
    non_speculative_fo_pnl = investments.select { |i| i.asset_class == "non_speculative_fo" }.sum(&:total_pnl).to_f
    crypto_pnl = investments.select { |i| i.asset_class == "crypto" }.sum(&:total_pnl).to_f

    # STCG & LTCG
    stcg_investments = investments.select(&:stcg?)
    ltcg_investments = investments.select(&:ltcg?)

    stcg_pnl = stcg_investments.sum(&:total_pnl).to_f
    ltcg_pnl = ltcg_investments.sum(&:total_pnl).to_f

    # 3. Deductions & Exemptions
    # 80C: ELSS investments + Home Loan principal
    elss_amount = investments.select { |i| i.asset_class == "elss_80c" }.sum(&:invested_amount).to_f
    home_loans = @user.loans.where(loan_type: "home")
    home_loan_principal = home_loans.sum { |l| l.principal_amount.to_f * (12.0 / l.tenure_months) }
    sec_80c = [elss_amount + home_loan_principal, 150_000.0].min

    # Section 24(b): Home Loan Interest
    home_loan_interest = home_loans.sum { |l| (l.emi_amount.to_f * 12) - (l.principal_amount.to_f * (12.0 / l.tenure_months)) }
    sec_24b_old = [home_loan_interest, 200_000.0].min

    # 4. Old vs New Tax Calculations
    # Standard Deductions
    std_deduction_new = 75_000.0
    std_deduction_old = 50_000.0

    # Taxable Income calculation
    # New Regime: Salary - 75,000 + Business/Trading P&L
    taxable_new = [gross_salary - std_deduction_new, 0].max + [non_speculative_fo_pnl, 0].max + [speculative_pnl, 0].max

    # Old Regime: Salary - 50,000 - 80C - 24b + Trading P&L
    taxable_old = [gross_salary - std_deduction_old - sec_80c - sec_24b_old, 0].max + [non_speculative_fo_pnl, 0].max + [speculative_pnl, 0].max

    # Tax liability calculations
    tax_new = calculate_new_regime_tax(taxable_new)
    tax_old = calculate_old_regime_tax(taxable_old)

    # Special Taxes
    # STCG (Sec 111A) @ 20%
    stcg_tax = stcg_pnl > 0 ? (stcg_pnl * 0.20).round(2) : 0.0
    # LTCG (Sec 112A) @ 12.5% on gains exceeding ₹1,25,000
    taxable_ltcg = [ltcg_pnl - 125_000.0, 0].max
    ltcg_tax = taxable_ltcg > 0 ? (taxable_ltcg * 0.125).round(2) : 0.0
    # Crypto (Sec 115BBH) @ 30%
    crypto_tax = crypto_pnl > 0 ? (crypto_pnl * 0.30).round(2) : 0.0

    total_tax_new = (tax_new[:total_tax] + stcg_tax + ltcg_tax + crypto_tax).round(2)
    total_tax_old = (tax_old[:total_tax] + stcg_tax + ltcg_tax + crypto_tax).round(2)

    recommended_regime = total_tax_new <= total_tax_old ? "New Tax Regime" : "Old Tax Regime"
    tax_saved = (total_tax_old - total_tax_new).abs.round(2)

    recommended_itr = if speculative_pnl != 0 || non_speculative_fo_pnl != 0
                        "ITR-3 (F&O / Speculative Trading Business Income)"
                      elsif stcg_pnl != 0 || ltcg_pnl != 0 || crypto_pnl != 0
                        "ITR-2 (Capital Gains & Crypto Income)"
                      else
                        "ITR-1 (Sahaj - Salary & Interest Income)"
                      end

    {
      financial_year: "FY #{@year - 1}-#{String(@year)[2..3]}",
      assessment_year: "AY #{@year}-#{String(@year + 1)[2..3]}",
      gross_salary: gross_salary,
      trading_summary: {
        speculative_intraday_pnl: speculative_pnl,
        non_speculative_fo_pnl: non_speculative_fo_pnl,
        crypto_pnl: crypto_pnl,
        stcg_pnl: stcg_pnl,
        ltcg_pnl: ltcg_pnl,
        total_pnl: speculative_pnl + non_speculative_fo_pnl + crypto_pnl + stcg_pnl + ltcg_pnl
      },
      deductions: {
        section_80c: sec_80c,
        section_24b_home_loan_interest: sec_24b_old,
        standard_deduction_new: std_deduction_new,
        standard_deduction_old: std_deduction_old
      },
      new_regime: {
        taxable_income: taxable_new,
        slab_tax: tax_new[:slab_tax],
        rebate_87a: tax_new[:rebate],
        total_tax: total_tax_new
      },
      old_regime: {
        taxable_income: taxable_old,
        slab_tax: tax_old[:slab_tax],
        rebate_87a: tax_old[:rebate],
        total_tax: total_tax_old
      },
      special_taxes: {
        stcg_tax_sec111a: stcg_tax,
        ltcg_tax_sec112a: ltcg_tax,
        crypto_tax_sec115bbh: crypto_tax
      },
      recommendation: {
        best_regime: recommended_regime,
        tax_saved: tax_saved,
        itr_form: recommended_itr
      }
    }
  end

  private

  def calculate_new_regime_tax(income)
    return { slab_tax: 0.0, rebate: 0.0, total_tax: 0.0 } if income <= 400_000

    tax = 0.0
    tax += (800_000 - 400_000) * 0.05 if income > 400_000
    tax += ([income, 1_200_000].min - 800_000) * 0.10 if income > 800_000
    tax += ([income, 1_600_000].min - 1_200_000) * 0.15 if income > 1_200_000
    tax += ([income, 2_000_000].min - 1_600_000) * 0.20 if income > 1_600_000
    tax += ([income, 2_400_000].min - 2_000_000) * 0.25 if income > 2_000_000
    tax += (income - 2_400_000) * 0.30 if income > 2_400_000

    # Section 87A rebate for New Regime up to 12 Lakhs
    if income <= 1_200_000
      { slab_tax: tax.round(2), rebate: tax.round(2), total_tax: 0.0 }
    else
      cess = (tax * 0.04).round(2) # 4% Health & Education Cess
      { slab_tax: tax.round(2), rebate: 0.0, total_tax: (tax + cess).round(2) }
    end
  end

  def calculate_old_regime_tax(income)
    return { slab_tax: 0.0, rebate: 0.0, total_tax: 0.0 } if income <= 250_000

    tax = 0.0
    tax += ([income, 500_000].min - 250_000) * 0.05 if income > 250_000
    tax += ([income, 1_000_000].min - 500_000) * 0.20 if income > 500_000
    tax += (income - 1_000_000) * 0.30 if income > 1_000_000

    # Section 87A rebate for Old Regime up to 5 Lakhs
    if income <= 500_000
      { slab_tax: tax.round(2), rebate: tax.round(2), total_tax: 0.0 }
    else
      cess = (tax * 0.04).round(2)
      { slab_tax: tax.round(2), rebate: 0.0, total_tax: (tax + cess).round(2) }
    end
  end
end
