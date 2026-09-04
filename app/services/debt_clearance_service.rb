# frozen_string_literal: true

# Aggregates the Debt Clearance Dashboard: the single screen that shows
# the whole war — total vs protected vs settlement debt, the settlement
# fund, the ranked pipeline, next target, cashflow split and the
# estimated debt-free date.
#
# Services return plain hashes; the controller camelizes at the boundary.
class DebtClearanceService
  def initialize(user)
    @user = user
  end

  def overview
    ranked = DebtQueueRanker.new(@user).call
    capital = SettlementCapitalService.new(@user).call
    forecast = DebtForecastEngine.new(@user).call

    {
      totals: debt_totals,
      settlement_fund: capital[:current_settlement_fund],
      fund_target: fund_target(ranked),
      next_settlement: next_settlement(ranked),
      estimated_debt_free_on: forecast.debt_free_on,
      forecast_months_used: forecast.months_used,
      total_settlement_cost: forecast.total_settlement_cost,
      pipeline: pipeline(ranked),
      cashflow: cashflow_view(capital),
      recent_contributions: recent_contributions,
      scenario_comparison: scenario_comparison
    }
  end

  # Per-account negotiation ladder for the case detail view.
  def scenario_table(settlement_case)
    SettlementCalculator.scenarios(
      claim_paise: settlement_case.current_claim_paise,
      service_fee_percentage: settlement_case.service_fee_percentage,
      gst_percentage: settlement_case.gst_percentage
    ).map do |r|
      {
        settlement_percentage: r[:settlement_percentage].to_f,
        settlement_amount: r[:settlement_amount_paise] / 100.0,
        service_fee: r[:service_fee_paise] / 100.0,
        gst: r[:gst_paise] / 100.0,
        total: r[:total_paise] / 100.0
      }
    end
  end

  private

  def debt_totals
    accounts = @user.debt_accounts.open
    settlement_total = accounts.settlement.sum(:current_balance_paise)
    protected_total = accounts.serviced.sum(:current_balance_paise)

    {
      total_debt: (settlement_total + protected_total) / 100.0,
      protected_debt: protected_total / 100.0,
      settlement_debt: settlement_total / 100.0,
      settlement_accounts: accounts.settlement.count,
      protected_accounts: accounts.serviced.count
    }
  end

  # The worst-case amount the pipeline still needs (max-cost estimate).
  def fund_target(ranked)
    ranked.sum { |e| e.estimated_total_paise } / 100.0
  end

  def next_settlement(ranked)
    entry = ranked.first
    return nil if entry.nil?

    c = entry.settlement_case
    {
      settlement_case_id: c.id,
      name: entry.debt_account.name,
      lender: entry.debt_account.lender,
      claim: c.current_claim.to_f,
      estimated_total: entry.estimated_total_paise / 100.0,
      stage: entry.stage,
      status: c.status,
      eligible: entry.eligible,
      funding_progress: entry.funding_progress
    }
  end

  def pipeline(ranked)
    ranked.map do |entry|
      c = entry.settlement_case
      {
        settlement_case_id: c.id,
        debt_account_id: entry.debt_account.id,
        name: entry.debt_account.name,
        lender: entry.debt_account.lender,
        claim: c.current_claim.to_f,
        estimated_total: entry.estimated_total_paise / 100.0,
        min_total: entry.min_total_paise / 100.0,
        stage: entry.stage,
        score: entry.score,
        breakdown: entry.breakdown,
        status: c.status,
        priority: c.priority,
        funding_progress: entry.funding_progress,
        eligible: entry.eligible,
        monthly_contribution: c.monthly_contribution.to_f,
        settlement_fund: c.settlement_fund_paise / 100.0
      }
    end
  end

  def cashflow_view(capital)
    {
      income: capital[:monthly_income],
      commitments: capital[:monthly_commitments],
      emergency_buffer: capital[:emergency_buffer],
      available_monthly_surplus: capital[:available_monthly_surplus],
      settlement_allocation: capital[:settlement_allocation],
      cash_on_hand: capital[:cash_on_hand],
      current_settlement_fund: capital[:current_settlement_fund],
      projected_settlement_capital: capital[:projected_settlement_capital],
      scenario_name: capital[:scenario_name]
    }
  end

  def recent_contributions
    @user.settlement_contributions.latest_first.limit(8).map do |c|
      {
        id: c.id,
        settlement_case_id: c.settlement_case_id,
        contributed_on: c.contributed_on,
        amount: c.amount.to_f,
        source: c.source
      }
    end
  end

  def scenario_comparison
    DebtForecastEngine.new(@user).scenarios.map do |s|
      {
        label: s[:label],
        monthly_allocation: s[:monthly_allocation],
        debt_free_on: s[:result].debt_free_on,
        months_used: s[:result].months_used,
        total_settlement_cost: s[:result].total_settlement_cost,
        settlements: s[:result].settlements
      }
    end
  end
end
