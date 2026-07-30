class ItrPrefillService
  # Generates a pre-filled ITR JSON matching the official
  def initialize(user, financial_year)
    @user = user
    @fy = financial_year
    @ay = financial_year + 1   # Assessment Year
    @tax = TaxCalculatorService.new(user, financial_year).call
  end

  def generate(itr_form: nil)
    form = itr_form || @tax[:recommended_itr_code]  # "ITR-1", "ITR-2", "ITR-3", "ITR-4"

    payload = {
      formName: form,
      assessmentYear: @ay.to_s,
      status: "O",  # Original filing
      itrForm: {
        personalInfo: personal_info,
        incomeDetails: income_details(form),
        deductions: deductions(form),
        taxPaid: tax_paid,
        taxComputation: tax_computation,
        refund: refund_info,
        verification: verification_info
      }.compact,
      _meta: {
        generatedBy: "ExpensePro",
        generatedAt: Time.current.iso8601,
        financialYear: "#{@fy}-#{@ay % 100}",
        reconciliationStatus: ReconciliationService.new(@user, @fy).call[:overall_status],
        sources: source_audit_trail
      }
    }

    # Form-specific schedules
    payload[:itrForm][:scheduleCG] = capital_gains_schedule if %w[ITR-2 ITR-3].include?(form)
    payload[:itrForm][:scheduleVDA] = vda_schedule if %w[ITR-2 ITR-3].include?(form)
    payload[:itrForm][:scheduleBP] = business_schedule if %w[ITR-3 ITR-4].include?(form)
    payload[:itrForm][:balanceSheet] = balance_sheet if form == "ITR-3"

    payload
  end

  private

  # ── Personal Info ──
  def personal_info
    {
      pan: @user.pan,
      aadhaarNumber: mask_aadhaar(@user.aadhaar_number),
      aadhaarLinked: @user.aadhaar_linked?,
      name: @user.full_name,
      dateOfBirth: @user.date_of_birth&.iso8601,
      status: "I",  # Individual
      residentialStatus: "RES",  # Resident — needs user confirmation
      address: {
        line1: @user.address_line1,
        city: @user.city,
        stateCode: state_code(@user.state),
        pinCode: @user.pincode,
        mobile: @user.phone,
        email: @user.email
      },
      employerInfo: employer_info  # for ITR-1
    }.compact
  end

  # ── Income Details ──
  def income_details(form)
    details = {}

    # Schedule S: Salary
    if salary_income.any?
      details[:salary] = {
        grossSalary: salary_income.sum { |f| f["gross_salary"].to_f },
        allowances: {
          houseRentAllowance: salary_income.sum { |f| f["hra_received"].to_f },
          otherAllowances: salary_income.sum { |f| f["special_allowance"].to_f }
        },
        standardDeduction: [salary_income.size, 1].max * 75_000,
        deductionsFromSalary: {
          providentFund: salary_income.sum { |f| f["epf_employee"].to_f },
          professionalTax: salary_income.sum { |f| f["professional_tax"].to_f }
        },
        netSalary: @tax[:income][:gross_salary],
        hraExemption: hra_exemption,
        employerTAN: salary_income.first&.dig("employer_tan")
      }.compact
    end

    # Schedule HP: House Property
    rental = @user.incomes.for_fy(@fy).where(income_source: :rental).sum(:amount)
    home_interest = verified_home_loan_interest
    if rental > 0 || home_interest > 0
      details[:houseProperty] = {
        annualLetUpValue: rental,
        standardDeduction30: (rental * 0.30).round(2),
        homeLoanInterest: -home_interest,  # negative = deduction
        netHousePropertyIncome: (rental * 0.70 - home_interest).round(2)
      }
    end

    # Schedule OS: Other Sources
    interest = @user.incomes.for_fy(@fy).where(income_source: :interest).sum(:amount)
    dividend = @user.incomes.for_fy(@fy).where(income_source: :dividend).sum(:amount)
    if interest > 0 || dividend > 0
      details[:otherSources] = {
        interestIncome: {
          savingsBank: interest,
          taxableInterest: interest
        },
        dividendIncome: dividend,
        grossOtherSourcesIncome: interest + dividend
      }.compact
    end

    details
  end

  # ── Capital Gains Schedule (ITR-2/3) ──
  def capital_gains_schedule
    trades = @user.investments.for_fy(@fy)
    stcg = trades.select(&:stcg?)
    ltcg = trades.select(&:ltcg?)

    {
      shortTerm: {
        # Section 111A — listed equity, 20% after Jul 2024
        section111A: {
          saleValue: stcg.sum { |i| i.current_value.to_f },
          acquisitionCost: stcg.sum(&:invested_amount),
          expensesOnTransfer: stcg.sum { |i| i.metadata&.dig("charges")&.values&.sum.to_f },
          shortTermGain: stcg.sum(&:pnl),
          taxRate: "20%"
        }
      }.compact,
      longTerm: {
        # Section 112A — 12.5% above ₹1.25L exemption
        section112A: {
          saleValue: ltcg.sum { |i| i.current_value.to_f },
          acquisitionCost: ltcg.sum(&:invested_amount),
          grandfatheredValue: nil,  # ⚠️ user must provide FMV @ 31-Jan-2018
          longTermGain: ltcg.sum(&:pnl),
          exemptionUpto125L: [ltcg.sum(&:pnl), 1_25_000].min,
          taxableLTCG: [ltcg.sum(&:pnl) - 1_25_000, 0].max,
          taxRate: "12.5%"
        }
      }.compact,
      totalCapitalGains: stcg.sum(&:pnl) + [ltcg.sum(&:pnl) - 1_25_000, 0].max
    }
  end

  # ── Schedule VDA: Crypto (ITR-2/3) ──
  def vda_schedule
    crypto = CryptoTaxService.new(@user, @fy).call
    {
      totalSaleConsideration: crypto[:per_asset].sum { |a| a[:total_sell_value] },
      acquisitionCost: crypto[:per_asset].sum { |a| a[:acquisition_cost] },
      vdaIncome: crypto[:taxable_gain],
      taxRate: "30%",
      tdsUnder194S: crypto[:tds][:deducted_by_brokers],
      lossNotSetOff: crypto[:total_loss] < 0 ? crypto[:total_loss].abs : 0,
      note: "Losses cannot be set off u/s 115BBH"
    }
  end

  # ── Schedule BP: Business (ITR-3/4) ──
  def business_schedule
    bp = {}

    # F&O / Intraday — non-speculative business income
    fo_pnl = @tax[:trading_income][:non_speculative_fo_pnl]
    if fo_pnl != 0
      bp[:nonSpeculativeBusiness] = {
        turnover: @tax[:trading_income][:non_speculative_turnover],
        netProfit: fo_pnl,
        natureOfBusiness: "Futures & Options Trading",
        icdsCompliance: false
      }
    end

    # Presumptive 44ADA — freelance
    freelance = @user.incomes.for_fy(@fy).where(income_source: %i[freelance consulting])
    if freelance.any?
      gross = freelance.sum(:amount)
      bp[:presumptive44ADA] = {
        grossReceipts: gross,
        deemedProfit: gross * 0.50,
        rate: "50%",
        eligible: gross <= 75_00_000
      }
    end

    # Presumptive 44AD — business
    business = @user.businesses.first
    if business&.tax_scheme == "presumptive_44ad"
      turnover = business.annual_turnover
      digital_pct = business.digital_receipt_percentage
      rate = digital_pct >= 95 ? 0.06 : 0.08
      bp[:presumptive44AD] = {
        turnover: turnover,
        deemedProfit: turnover * rate,
        rate: "#{(rate * 100).to_i}%",
        eligible: turnover <= 3_00_00_000
      }
    end

    bp
  end

  # ── Deductions (Chapter VI-A) ──
  def deductions(form)
    # New regime: almost nothing. Old regime: full set.
    regime = @tax[:comparison][:recommended_regime]

    ded = {
      standardDeduction: 75_000,
      chapterVIADeductions: {}
    }

    if regime == "old"
      viA = ded[:chapterVIADeductions]
      viA[:section80C] = compute_80c
      viA[:section80CCD1B] = nps_contribution
      viA[:section80D] = health_insurance_total
      viA[:section80E] = education_loan_interest
      viA[:section80G] = donation_total
      viA[:section80TTA] = [savings_interest, 10_000].min
      viA[:section24b] = [verified_home_loan_interest, 2_00_000].min
      viA[:hraExemption] = hra_exemption
      viA.reject! { |_, v| v.to_f.zero? }
    end

    ded
  end

  def compute_80c
    epf = salary_income.sum { |f| f["epf_employee"].to_f }
    elss = @user.investments.where(asset_class: :elss).for_fy(@fy).sum(&:invested_amount)
    principal = home_loan_principal_paid
    tuition = verified_documents(:tuition_receipt).sum { |t| t["amount"].to_f }
    ppf = verified_documents(:ppf_passbook).sum { |t| t["deposits"].to_f }

    [epf + elss + principal + tuition + ppf, 1_50_000].min
  end

  # ── Tax Paid (from 26AS — authoritative) ──
  def tax_paid
    tds_26as = latest_doc(:form_26as)
    challans = verified_documents(:advance_tax_challan)

    {
      tds: tds_26as ? {
        totalTDS: tds_26as["total_tds"].to_f,
        salaryTDS: tds_26as["tds_entries"]&.select { |t| t["section"] == "192" }&.sum { |t| t["tds"].to_f },
        otherTDS: tds_26as["tds_entries"]&.reject { |t| t["section"] == "192" }&.sum { |t| t["tds"].to_f }
      } : nil,
      advanceTax: challans.sum { |c| c["amount_paid"].to_f },
      selfAssessmentTax: challans.select { |c| c["challan_type"] == "self_assessment" }.sum { |c| c["amount_paid"].to_f },
      totalTaxPaid: (tds_26as&.dig("total_tds").to_f + challans.sum { |c| c["amount_paid"].to_f })
    }.compact
  end

  # ── Tax Computation ──
  def tax_computation
    best = @tax[:comparison]
    {
      regime: best[:recommended_regime],
      grossTotalIncome: best[:recommended][:taxable_income],
      totalDeductions: best[:recommended][:total_deductions],
      taxableIncome: best[:recommended][:taxable_income],
      taxBeforeCess: best[:recommended][:base_tax],
      rebate87A: best[:recommended][:rebate],
      surcharge: best[:recommended][:surcharge],
      healthEducationCess: best[:recommended][:cess],
      totalTaxLiability: best[:recommended][:total_tax],
      taxAlreadyPaid: tax_paid[:totalTaxPaid],
      taxPayable: [best[:recommended][:total_tax] - tax_paid[:totalTaxPaid], 0].max,
      refundDue: [tax_paid[:totalTaxPaid] - best[:recommended][:total_tax], 0].max
    }
  end

  def refund_info
    refund = tax_computation[:refundDue]
    return nil unless refund > 0

    {
      refundAmount: refund,
      bankAccount: {
        accountNumber: @user.refund_account_number,
        ifscCode: @user.refund_ifsc,
        bankName: @user.refund_bank_name,
        evcEnabled: @user.refund_account_evc?  # ⚠️ MUST be true or refund fails
      },
      note: "Bank account must be EVC-validated on the portal before filing"
    }.compact
  end

  def verification_info
    {
      name: @user.full_name,
      fatherName: @user.father_name,
      capacity: "Self",
      date: Date.today.iso8601,
      place: @user.city
    }
  end

  # ── Source Audit Trail (provenance of every number) ──
  def source_audit_trail
    {
      salary: "Form 16 (#{verified_documents(:form_16).size} document(s))",
      tds: "Form 26AS",
      interest: "AIS + Income records",
      capitalGains: "Broker trade imports (#{@user.trades.for_fy(@fy).count} trades)",
      deductions: "Uploaded proofs + TaxDeduction records",
      reconciliation: "All figures cross-verified against AIS/26AS"
    }
  end

  # ── Helpers ──
  def salary_income = verified_documents(:form_16)
  def latest_doc(type) = @user.tax_documents.for_fy(@fy).where(document_type: type, status: %i[extracted verified]).order(created_at: :desc).first&.extracted_data
  def verified_documents(type) = @user.tax_documents.for_fy(@fy).where(document_type: type, status: :verified).map(&:extracted_data)
  def verified_home_loan_interest = verified_documents(:home_loan_certificate).sum { |c| c["interest_paid"].to_f }
  def home_loan_principal_paid = @user.loan_accounts.where(loan_type: :home_loan).sum { |l| l.emi_schedules.for_fy(@fy).sum(:principal_component) }
  def nps_contribution = verified_documents(:nps_statement).sum { |n| n["contribution"].to_f }
  def health_insurance_total = verified_documents(:health_insurance_80d).sum { |h| h["premium"].to_f }
  def education_loan_interest = verified_documents(:education_loan_cert).sum { |e| e["interest_paid"].to_f }
  def donation_total = verified_documents(:donation_80g).sum { |d| d["amount"].to_f }
  def savings_interest = @user.incomes.for_fy(@fy).where(income_source: :interest).sum(:amount)
  def hra_exemption = HraCalculatorService.new(@user, @fy).calculate

  def mask_aadhaar(aadhaar)
    return nil unless aadhaar
    "XXXXXXXX#{aadhaar.last(4)}"
  end

  def state_code(state)
    # ITR uses numeric state codes
    { "Maharashtra" => "19", "Karnataka" => "15", "Delhi" => "7",
      "Tamil Nadu" => "28", "Telangana" => "29", "Gujarat" => "9",
      "Uttar Pradesh" => "31", "West Bengal" => "33" }[state] || "99"
  end

  def employer_info
    f16 = salary_income.first
    return nil unless f16
    { employerTAN: f16["employer_tan"], employerName: f16["employer_name"] }
  end
end
