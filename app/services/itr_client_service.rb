# frozen_string_literal: true

# ItrClientService - HTTP client for the Python ITR tax microservice
# This service wraps calls to the india-itr-copilot based tax engine,
# allowing ExpensePro to leverage accurate, tested tax computation
# without rewriting the logic in Ruby.
#
# Features delegated to Python service:
# - Head-based F&O loss set-off with carry-forward
# - Component-wise surcharge with 15% CG cap
# - Marginal relief on 87A rebate and surcharge boundaries
# - Section 288B rounding (nearest ₹10, ties up)
# - Full Chapter VI-A deductions (80D structured, 80TTA/B, HRA)
# - Complete interest calculator (234A/B/C/F)
# - Rules registry driven by JSON files per Assessment Year

class ItrClientService
  include Singleton

  class ServiceUnavailableError < StandardError; end
  class CalculationError < StandardError; end

  BASE_URL = ENV.fetch('ITR_SERVICE_URL', 'http://localhost:8000')
  TIMEOUT = ENV.fetch('ITR_SERVICE_TIMEOUT', '10').to_i
  RETRY_COUNT = ENV.fetch('ITR_SERVICE_RETRY', '2').to_i

  def initialize
    @http = HTTPClient.new
    @http.receive_timeout = TIMEOUT
    @http.connect_timeout = TIMEOUT
  end

  # Calculate tax for both regimes and return recommendation
  # @param user [User]
  # @param financial_year [Integer]
  # @return [Hash] complete tax calculation result
  def calculate_tax(user, financial_year = nil)
    year = financial_year || default_financial_year
    assessment_year = "AY#{year + 1}-#{(year + 1) + 1}"

    request_payload = build_tax_request(user, year, assessment_year)

    response = post_with_retry('/calculate', request_payload)

    if response.success?
      parse_response(response.body, user, year)
    else
      Rails.logger.error "ITR service error: #{response.body}"
      raise CalculationError, "Tax calculation failed: #{response.code}"
    end
  rescue HTTPClient::TimeoutError, Errno::ECONNREFUSED => e
    Rails.logger.error "ITR service unavailable: #{e.message}"
    raise ServiceUnavailableError, "Tax calculation service is temporarily unavailable"
  end

  # Quick comparison of regimes for simple salary income
  # @param gross_income [Float]
  # @param assessment_year [String]
  # @return [Hash] regime comparison result
  def compare_regimes(gross_income, assessment_year = 'AY2026-27')
    url = "#{BASE_URL}/compare-regimes"
    params = {
      gross_income: gross_income,
      assessment_year: assessment_year
    }

    response = @http.get(url, query: params)

    if response.status == 200
      JSON.parse(response.body)
    else
      raise CalculationError, "Regime comparison failed: #{response.status}"
    end
  rescue HTTPClient::TimeoutError, Errno::ECONNREFUSED => e
    Rails.logger.error "ITR service unavailable: #{e.message}"
    raise ServiceUnavailableError, "Tax comparison service is temporarily unavailable"
  end

  # Get tax rules for a specific assessment year
  # @param assessment_year [String]
  # @return [Hash] tax rules configuration
  def get_rules(assessment_year)
    url = "#{BASE_URL}/rules/#{assessment_year}"
    response = @http.get(url)

    if response.status == 200
      JSON.parse(response.body)
    else
      Rails.logger.warn "Rules not found for #{assessment_year}, using defaults"
      default_rules(assessment_year)
    end
  rescue HTTPClient::TimeoutError, Errno::ECONNREFUSED => e
    Rails.logger.error "ITR service unavailable: #{e.message}"
    default_rules(assessment_year)
  end

  # Health check for the ITR service
  # @return [Boolean]
  def healthy?
    url = "#{BASE_URL}/health"
    response = @http.get(url, timeout: 3)
    response.status == 200
  rescue HTTPClient::TimeoutError, Errno::ECONNREFUSED
    false
  end

  private

  def post_with_retry(endpoint, payload)
    url = "#{BASE_URL}#{endpoint}"
    attempts = 0

    begin
      attempts += 1
      response = @http.post(
        url,
        body: payload.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
      response
    rescue HTTPClient::TimeoutError, Errno::ECONNREFUSED => e
      if attempts <= RETRY_COUNT
        Rails.logger.warn "ITR service retry #{attempts}/#{RETRY_COUNT}: #{e.message}"
        sleep(attempts * 0.5)
        retry
      else
        raise
      end
    end
  end

  def build_tax_request(user, financial_year, assessment_year)
    start_date = Date.new(financial_year, 4, 1)
    end_date = Date.new(financial_year + 1, 3, 31)

    # Gather income data from user's records
    incomes = IncomeProjectionService.new(user, start_date, end_date).call

    salary_incomes = incomes.select { |i| %w[salary bonus fnf].include?(i.income_type) || i.income_type.blank? }
    gross_salary = salary_incomes.sum { |inc| (inc.gross_amount || inc.amount).to_f }

    freelance_incomes = incomes.select { |i| i.income_type == 'freelance' }
    gross_freelance = freelance_incomes.sum { |inc| (inc.gross_amount || inc.amount).to_f }

    interest_incomes = incomes.select { |i| %w[interest fd_interest].include?(i.income_type) }
    gross_interest = interest_incomes.sum { |inc| (inc.gross_amount || inc.amount).to_f }

    dividend_incomes = incomes.select { |i| i.income_type == 'dividend' }
    gross_dividend = dividend_incomes.sum { |inc| (inc.gross_amount || inc.amount).to_f }

    # TDS
    tds_from_incomes = incomes.sum { |inc| inc.tax_deducted.to_f }
    tds_from_deductions = TaxDeduction.for_fy(financial_year + 1).sum(:tds_amount).to_f
    total_tds = tds_from_incomes + tds_from_deductions

    # Investment P&L
    investments = user.investments
      .where(purchase_date: start_date..end_date)
      .or(user.investments.where(status: 'realized', sell_date: start_date..end_date))

    speculative_pnl = investments.select { |i| i.asset_class == 'speculative_intraday' }.sum(&:total_pnl).to_f
    non_speculative_fo_pnl = investments.select { |i| i.asset_class == 'non_speculative_fo' }.sum(&:total_pnl).to_f
    crypto_pnl = investments.select { |i| i.asset_class == 'crypto' }.sum(&:total_pnl).to_f
    fixed_income_pnl = investments.select { |i| i.asset_class == 'fixed_income' }.sum(&:total_pnl).to_f

    gold_investments = investments.select { |i| i.asset_class == 'gold' }
    gold_stcg = gold_investments.select { |i| (i.sell_date || Date.current) - i.purchase_date < 1095 }.sum(&:total_pnl).to_f
    gold_ltcg = gold_investments.select { |i| (i.sell_date || Date.current) - i.purchase_date >= 1095 }.sum(&:total_pnl).to_f

    stcg_investments = investments.select(&:stcg?)
    ltcg_investments = investments.select(&:ltcg?)
    stcg_pnl = stcg_investments.sum(&:total_pnl).to_f
    ltcg_pnl = ltcg_investments.sum(&:total_pnl).to_f

    # Deductions
    section_80c = calculate_section_80c(user, start_date, end_date, investments)
    section_80d = calculate_section_80d(user, start_date, end_date)
    section_80ccd_1b = calculate_section_80ccd_1b(investments)
    hra_exemption = calculate_hra_exemption(user, start_date, end_date)
    home_loan_interest = calculate_home_loan_interest(user, start_date, end_date)

    # Taxpayer profile
    age = user.date_of_birth ? ((Date.current - user.date_of_birth).to_i / 365) : 30
    is_senior = age >= 60
    is_super_senior = age >= 80

    {
      assessment_year: assessment_year,
      income: {
        gross_salary: gross_salary,
        freelance_income: gross_freelance,
        interest_income: gross_interest,
        dividend_income: gross_dividend,
        speculative_pnl: speculative_pnl,
        non_speculative_fo_pnl: non_speculative_fo_pnl,
        crypto_pnl: crypto_pnl,
        fixed_income_pnl: fixed_income_pnl,
        gold_stcg: gold_stcg,
        gold_ltcg: gold_ltcg,
        stcg_111a: stcg_pnl,
        ltcg_112a: ltcg_pnl,
        house_property_income: 0.0
      },
      deductions: {
        section_80c: section_80c,
        section_80d_self: section_80d[:self],
        section_80d_parents: section_80d[:parents],
        section_80d_senior_parent: 0.0,
        section_80ccd_1b: section_80ccd_1b,
        section_80tta: 0.0,
        section_80ttb: 0.0,
        hra_exemption: hra_exemption,
        home_loan_interest: home_loan_interest,
        standard_deduction: 0.0 # Will use regime default
      },
      taxpayer: {
        age: age,
        is_senior_citizen: is_senior,
        is_super_senior: is_super_senior,
        is_resident: true,
        has_presumptive_income: gross_freelance > 0 && gross_freelance <= 75_00_000
      },
      tds_paid: total_tds,
      advance_tax_paid: 0.0,
      regime_preference: 'both'
    }
  end

  def calculate_section_80c(user, start_date, end_date, investments)
    elss = investments.select { |i| i.asset_class == 'elss_80c' }.sum(&:invested_amount).to_f
    principal = user.loans.where(loan_type: 'home').sum do |l|
      l.emi_payments.where(due_date: start_date..end_date).sum(:principal_amount).to_f
    end
    [elss + principal, 150_000].min
  end

  def calculate_section_80d(user, start_date, end_date)
    health_category_ids = user.categories.where(name: 'Health', category_type: 'expense').pluck(:id)
    total = 0.0
    if health_category_ids.any?
      total = user.expenses
        .where(category_id: health_category_ids, expense_date: start_date..end_date)
        .sum(:amount).to_f
    end
    { self: [total, 25_000].min, parents: 0.0 }
  end

  def calculate_section_80ccd_1b(investments)
    nps = investments.select { |i| i.asset_class == 'nps' }.sum(&:invested_amount).to_f
    [nps, 50_000].min
  end

  def calculate_hra_exemption(user, start_date, end_date)
    total = 0.0
    active_employments = user.employments.select do |e|
      e_start = e.start_date
      e_end = e.end_date || Date.current
      e_start <= end_date && e_end >= start_date
    end

    active_employments.each do |employment|
      result = HraExemptionService.new(employment).call
      total += result[:hra_exempt].to_f
    end
    total
  end

  def calculate_home_loan_interest(user, start_date, end_date)
    user.loans.where(loan_type: 'home').sum do |l|
      interest = l.emi_payments.where(due_date: start_date..end_date).sum(:interest_amount).to_f
      l.respond_to?(:occupancy) && l.occupancy == 'let_out' ? interest : [interest, 200_000].min
    end
  end

  def parse_response(response_body, user, year)
    data = JSON.parse(response_body)

    recommended = data['recommended_regime'].downcase.include?('new') ? 'new' : 'old'
    recommended_result = recommended == 'new' ? data['new_regime'] : data['old_regime']

    {
      financial_year: "#{year}-#{year + 1}",
      assessment_year: data['assessment_year'],
      gross_total_income: recommended_result['gross_total_income'],
      taxable_income: recommended_result['taxable_income'],
      recommendation: {
        best_regime: data['recommended_regime'],
        tax_saved: data['tax_saved_by_recommendation'],
        itr_form: extract_itr_form(data['compliance_notes'])
      },
      trading_summary: build_trading_summary(data),
      new_regime: format_regime_detail(data['new_regime']),
      old_regime: format_regime_detail(data['old_regime']),
      deductions: format_deductions(data),
      special_taxes: recommended_result['special_taxes'],
      compliance_notes: data['compliance_notes'],
      refund_due: data['refund_due'],
      tax_payable: data['total_tax_payable']
    }
  end

  def extract_itr_form(compliance_notes)
    note = compliance_notes.find { |n| n.include?('ITR Form') }
    return 'ITR-1' unless note

    if note.include?('ITR-3')
      'ITR-3'
    elsif note.include?('ITR-2')
      'ITR-2'
    else
      'ITR-1'
    end
  end

  def build_trading_summary(data)
    old_regime = data['old_regime'] || {}
    new_regime = data['new_regime'] || {}
    losses = old_regime['unabsorbed_losses'] || new_regime['unabsorbed_losses'] || {}

    {
      speculative_intraday_pnl: 0.0, # Would need to pass through from request
      non_speculative_fo_pnl: 0.0,
      stcg_pnl: 0.0,
      ltcg_pnl: 0.0,
      crypto_pnl: 0.0,
      total_pnl: 0.0,
      unabsorbed_losses: losses
    }
  end

  def format_regime_detail(regime_data)
    return {} unless regime_data

    {
      taxable_income: regime_data['taxable_income'],
      slab_tax: regime_data['slab_tax'],
      rebate_87a: regime_data['rebate_87a'],
      marginal_relief_applied: regime_data['marginal_relief_on_rebate'] || regime_data['marginal_relief_on_surcharge'],
      base_tax: regime_data['base_tax_after_rebate'],
      surcharge: regime_data['surcharge'],
      cess: regime_data['cess'],
      total_tax: regime_data['total_tax_rounded'],
      deductions_used: regime_data['deductions_used']
    }
  end

  def format_deductions(data)
    old_deductions = data.dig('old_regime', 'deductions_used') || {}
    new_deductions = data.dig('new_regime', 'deductions_used') || {}

    {
      standard_deduction_new: new_deductions['standard_deduction'] || 75_000,
      standard_deduction_old: 50_000,
      section_80c: old_deductions['section_80c'] || 0,
      section_80d: old_deductions['section_80d'] || 0,
      section_24b_home_loan_interest: old_deductions['section_24b'] || 0,
      section_80ccd_1b: old_deductions['section_80ccd_1b'] || 0,
      hra: old_deductions['hra'] || 0
    }
  end

  def default_rules(assessment_year)
    {
      'assessment_year' => assessment_year,
      'old_regime' => {
        'slabs' => [
          { 'limit' => 250_000, 'rate' => 0.0 },
          { 'limit' => 500_000, 'rate' => 0.05 },
          { 'limit' => 1_000_000, 'rate' => 0.20 },
          { 'limit' => nil, 'rate' => 0.30 }
        ],
        'standard_deduction' => 50_000
      },
      'new_regime' => {
        'slabs' => [
          { 'limit' => 400_000, 'rate' => 0.0 },
          { 'limit' => 800_000, 'rate' => 0.05 },
          { 'limit' => 1_200_000, 'rate' => 0.10 },
          { 'limit' => 1_600_000, 'rate' => 0.15 },
          { 'limit' => 2_000_000, 'rate' => 0.20 },
          { 'limit' => 2_400_000, 'rate' => 0.25 },
          { 'limit' => nil, 'rate' => 0.30 }
        ],
        'standard_deduction' => 75_000
      }
    }
  end

  def default_financial_year
    today = Date.current
    today.month >= 4 ? today.year : today.year - 1
  end
end
