# frozen_string_literal: true

# Projects WHEN each settlement becomes fundable, and when the user is
# debt-free.
#
#   current settlement fund
#     + monthly allocation            (scenario / strategy / explicit)
#     + cashflow released by earlier settlements
#     − settlement costs when a case is funded
#     = projected settlement date per case
#
# The simulation runs in queue order (DebtQueueRanker) with a hard cap of
# MAX_MONTHS so pathological inputs cannot loop forever. A case settles
# in the first month its accumulated fund covers its estimated maximum
# cost (target_max_percentage) — the conservative assumption.
class DebtForecastEngine
  MAX_MONTHS = 120

  DEFAULT_SCENARIO_ALLOCATIONS = [10_000, 15_000, 30_000, 40_000].freeze

  Result = Struct.new(
    :monthly_allocation, :start_fund, :settlements, :months_used,
    :debt_free_on, :total_settlement_cost, keyword_init: true
  )

  def initialize(user, monthly_allocation: nil)
    @user = user
    @explicit_allocation = monthly_allocation
  end

  def call
    allocate_monthly(default_allocation, queue)
  end

  # Comparison view: conservative / base / appraisal / aggressive.
  def scenarios
    scenario_allocations.map do |label, amount|
      result = allocate_monthly(amount, queue)
      { label: label, monthly_allocation: amount, result: result }
    end
  end

  private

  def queue
    @queue ||= DebtQueueRanker.new(@user).call
  end

  def default_allocation
    return @explicit_allocation.to_f if @explicit_allocation.to_f.positive?

    active = @user.income_scenarios.active.order(:effective_on).last
    return active.settlement_allocation.to_f if active&.settlement_allocation&.positive?

    strategy = @user.debt_strategies.where(status: "active", is_default: true).first ||
               @user.debt_strategies.active.first
    return strategy.monthly_allocation.to_f if strategy&.monthly_allocation&.positive?

    SettlementCapitalService.new(@user).call[:settlement_allocation]
  end

  # Named scenarios: use saved income scenarios when present, else the
  # standard ladder used by the dashboard comparison chart.
  def scenario_allocations
    saved = @user.income_scenarios.where(scenario_type: %i[conservative base appraisal aggressive])
                 .order(:scenario_type)

    if saved.exists?
      saved.map { |s| [s.scenario_type.capitalize, s.settlement_allocation.to_f] }
    else
      DEFAULT_SCENARIO_ALLOCATIONS.map { |a| ["₹#{a / 1000}k", a.to_f] }
    end
  end

  def allocate_monthly(monthly_allocation, ranked_queue)
    start_fund = SettlementCapitalService.new(@user).call[:current_settlement_fund]
    fund = start_fund
    allocation = monthly_allocation.to_f
    settlements = []
    pending = ranked_queue.dup
    month = 0

    while pending.any? && month < MAX_MONTHS
      month += 1
      fund += allocation

      pending.dup.each do |entry|
        next unless fund >= entry.estimated_total_paise / 100.0

        cost = entry.estimated_total_paise / 100.0
        fund -= cost
        settlements << {
          settlement_case_id: entry.settlement_case.id,
          debt_account_id: entry.debt_account.id,
          name: entry.debt_account.name,
          lender: entry.debt_account.lender,
          month_number: month,
          projected_on: Date.current.advance(months: month),
          cost: cost.round(2),
          claim: entry.debt_account.current_balance.to_f,
          cashflow_released: entry.debt_account.monthly_cashflow_demand.round(2)
        }
        pending.delete(entry)
        # A settled account stops demanding EMI/minimums; its monthly cash
        # joins the settlement allocation from the following month.
        allocation += entry.debt_account.monthly_cashflow_demand
      end
    end

    last_month = settlements.map { |s| s[:month_number] }.max
    Result.new(
      monthly_allocation: monthly_allocation.to_f,
      start_fund: start_fund,
      settlements: settlements,
      months_used: last_month,
      debt_free_on: (Date.current.advance(months: last_month) if last_month),
      total_settlement_cost: settlements.sum { |s| s[:cost] }.round(2)
    )
  end
end
