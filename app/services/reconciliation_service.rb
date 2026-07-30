class ReconciliationService
  # Compares THREE sources of truth:
  #   1. App-computed data (Income, Trade, Investment, Loan models)
  #   2. Uploaded documents (Form 16, certificates)
  #   3. Department data (AIS + Form 26AS)
  #
  # Any variance beyond tolerance = a mismatch the user MUST resolve.

  TOLERANCE = 1.0  # ₹1 rounding tolerance

  def initialize(user, financial_year)
    @user = user
    @fy = financial_year
  end

  def call
    ais = latest_parsed(:ais_json)
    tds_26as = latest_parsed(:form_26as)
    form16s = all_parsed(:form_16)

    checks = []
    checks << check_salary(form16s, ais)
    checks << check_interest(ais)
    checks << check_dividend(ais)
    checks << check_equity_sales(ais)
    checks << check_tds_total(tds_26as, form16s)
    checks << check_home_loan_interest
    checks << check_advance_tax
    checks.compact!

    {
      financial_year: @fy,
      overall_status: overall_status(checks),
      warnings: checks.count { |c| c[:severity] == :warning },
      checks: checks,
      filing_ready: checks.none? { |c| c[:severity] == :critical }
    }
  end

  private

  # ── Check 1: Salary vs AIS TDS (Section 192) ──
  def check_salary(form16s, ais)
    return nil unless ais

    app_salary = @user.incomes.for_fy(@fy).where(income_source: :salary).sum(:amount)
    form16_salary = form16s.sum { |f| f["taxable_salary"].to_f }
    ais_salary_tds = ais["tds_entries"]&.select { |t| t["section"] == "192" }&.sum { |t| t["amount"].to_f } || 0

    variance = form16_salary - ais_salary_tds
    return nil if ais_salary_tds.zero? && form16_salary.zero?

    {
      item: "Salary Income",
      itr_schedule: "Schedule S",
      app_value: app_salary,
      document_value: form16_salary,
      department_value: ais_salary_tds,
      variance: variance.abs,
      severity: variance.abs > TOLERANCE ? :critical : :ok,
      resolution: variance.abs > TOLERANCE ?
        "Form 16 salary (#{inr(form16_salary)}) doesn't match AIS (#{inr(ais_salary_tds)}). Report the AIS figure or get a corrected Form 16 from employer — mismatch WILL trigger a notice." : nil
    }
  end

  # ── Check 2: Interest Income vs AIS ──
  def check_interest(ais)
    return nil unless ais

    app_interest = @user.incomes.for_fy(@fy).where(income_source: :interest).sum(:amount)
    ais_interest = ais["total_interest_reported"].to_f

    # Rule: you must report AT LEAST what AIS shows
    under_reported = ais_interest - app_interest

    {
      item: "Interest Income (Savings + FD)",
      itr_schedule: "Schedule OS",
      app_value: app_interest,
      department_value: ais_interest,
      variance: under_reported,
      severity: under_reported > TOLERANCE ? :critical : :ok,
      resolution: under_reported > TOLERANCE ?
        "Banks reported #{inr(ais_interest)} interest to the department, but app shows #{inr(app_interest)}. Add the missing #{inr(under_reported)} as interest income — the department matches this automatically." : nil
    }
  end

  # ── Check 3: Dividend vs AIS ──
  def check_dividend(ais)
    return nil unless ais

    app_dividend = @user.incomes.for_fy(@fy).where(income_source: :dividend).sum(:amount)
    ais_dividend = ais["total_dividend_reported"].to_f
    under_reported = ais_dividend - app_dividend

    {
      item: "Dividend Income",
      itr_schedule: "Schedule OS",
      app_value: app_dividend,
      department_value: ais_dividend,
      variance: under_reported,
      severity: under_reported > TOLERANCE ? :critical : :ok,
      resolution: under_reported > TOLERANCE ?
        "AIS shows #{inr(ais_dividend)} dividend. Report at least this amount." : nil
    }
  end

  # ── Check 4: Equity/MF Sale Value vs AIS SFT ──
  def check_equity_sales(ais)
    return nil unless ais

    # Department knows the SALE VALUE (not the gain). Your reported sale
    # proceeds must be ≥ AIS figure.
    app_sales = 0
    if defined?(@user.trades)
      app_sales = @user.trades.for_fy(@fy).where(trade_type: :sell).sum(:amount)
    end
    ais_sales = (ais["total_equity_sale_value"].to_f + ais["total_mf_sale_value"].to_f)

    under_reported = ais_sales - app_sales

    {
      item: "Share/MF Sale Proceeds",
      itr_schedule: "Schedule CG",
      app_value: app_sales,
      department_value: ais_sales,
      variance: under_reported,
      severity: under_reported > 10_000 ? :warning : :ok,  # tolerance: broker timing diffs
      resolution: under_reported > 10_000 ?
        "Brokers reported #{inr(ais_sales)} in sales to the department via SFT, but imported trades show #{inr(app_sales)}. Import trades from ALL brokers for the full FY, or verify off-exchange transfers." : nil
    }
  end

  # ── Check 5: Total TDS vs Form 26AS ──
  def check_tds_total(tds_26as, form16s)
    return nil unless tds_26as

    form16_tds = form16s.sum { |f| f["tds_deducted"].to_f }
    other_16a = all_parsed(:form_16a).sum { |f| f["tds_deducted"].to_f }
    claimed = form16_tds + other_16a
    dept_recorded = tds_26as["total_tds"].to_f

    variance = claimed - dept_recorded

    {
      item: "Total TDS Claimed",
      itr_schedule: "Tax Paid Schedule",
      document_value: claimed,
      department_value: dept_recorded,
      variance: variance.abs,
      severity: variance > TOLERANCE ? :critical : :ok,
      resolution: variance > TOLERANCE ?
        "You're claiming #{inr(claimed)} TDS but 26AS shows #{inr(dept_recorded)} deposited. Claim ONLY the 26AS figure — claiming more causes a refund delay and notice. Difference: #{inr(variance.abs)}." : nil
    }
  end

  # ── Check 6: Home Loan Interest vs App Amortization ──
  def check_home_loan_interest
    certs = all_parsed(:home_loan_certificate)
    return nil if certs.empty?

    cert_interest = certs.sum { |c| c["interest_paid"].to_f }
    app_interest = 0
    if defined?(@user.loan_accounts)
      app_interest = @user.loan_accounts
                         .where(loan_type: :home_loan, status: :active)
                         .sum { |l| l.emi_schedules.for_fy(@fy).sum(:interest_component) }
    end

    variance = (cert_interest - app_interest).abs

    {
      item: "Home Loan Interest (24b)",
      itr_schedule: "Schedule HP",
      document_value: cert_interest,
      app_value: app_interest,
      variance: variance,
      severity: variance > 1_000 ? :warning : :ok,
      resolution: variance > 1_000 ?
        "Bank certificate says #{inr(cert_interest)} interest; app amortization says #{inr(app_interest)}. Use the bank certificate figure (it's authoritative)." : nil
    }
  end

  # ── Check 7: Advance Tax vs Challans ──
  def check_advance_tax
    challans = all_parsed(:advance_tax_challan)
    return nil if challans.empty?

    paid = challans.sum { |c| c["amount_paid"].to_f }
    required = TaxCalculatorService.new(@user, @fy).call.dig(:advance_tax_required) || 0

    {
      item: "Advance Tax Paid",
      itr_schedule: "Tax Paid Schedule",
      document_value: paid,
      app_value: required,
      variance: (required - paid),
      severity: required - paid > 10_000 ? :warning : :ok,
      resolution: required - paid > 10_000 ?
        "Estimated liability is #{inr(required)} but challans show #{inr(paid)} paid. Pay the balance via challan ITNS-280 before March 31 to avoid 234C interest." : nil
    }
  end

  def overall_status(checks)
    return :filing_ready if checks.none? { |c| c[:severity] == :critical }
    return :needs_attention if checks.any? { |c| c[:severity] == :critical }
    :ok
  end

  def latest_parsed(type)
    @user.tax_documents.for_fy(@fy).where(document_type: type, status: %i[extracted verified])
         .order(created_at: :desc).first&.extracted_data
  end

  def all_parsed(type)
    @user.tax_documents.for_fy(@fy).where(document_type: type, status: %i[extracted verified])
         .map(&:extracted_data)
  end

  def inr(amount)
    "₹#{amount.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end
end
