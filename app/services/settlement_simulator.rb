# frozen_string_literal: true

# Answers the recurring question: "When I have money, where should it go?"
#
# Given a lump of available capital, the simulator walks the settlement
# queue cheapest-first (formal/legal opportunities always first) and
# commits cash to every account it can fully fund:
#
#   ₹1,00,000 available
#     -> Account A ₹18,000   settled
#     -> Account B ₹27,000   settled
#     -> Account C ₹32,000   settled
#     -> ₹23,000 remaining, next target + shortfall
#
# The output also reports how much monthly cashflow the eliminated
# accounts release, which is what makes small accounts attractive.
class SettlementSimulator
  def initialize(user)
    @user = user
  end

  def call(available_cash:)
    available = available_cash.to_f
    queue = DebtQueueRanker.new(@user).call
    targets = queue.sort_by { |e| [e.stage, e.estimated_total_paise] }

    cash = available
    allocations = []
    cashflow_released = 0.0

    targets.each do |entry|
      cost = entry.estimated_total_paise / 100.0
      break if cash < cost

      allocations << {
        settlement_case_id: entry.settlement_case.id,
        debt_account_id: entry.debt_account.id,
        name: entry.debt_account.name,
        lender: entry.debt_account.lender,
        claim: entry.debt_account.current_balance.to_f,
        stage: entry.stage,
        settlement_cost: cost.round(2),
        cashflow_released: entry.debt_account.monthly_cashflow_demand.round(2)
      }
      cash -= cost
      cashflow_released += entry.debt_account.monthly_cashflow_demand
    end

    {
      available_cash: available.round(2),
      allocations: allocations,
      accounts_eliminated: allocations.size,
      debt_removed: allocations.sum { |a| a[:claim] }.round(2),
      total_settlement_cost: allocations.sum { |a| a[:settlement_cost] }.round(2),
      monthly_cashflow_recovered: cashflow_released.round(2),
      remaining_cash: cash.round(2),
      next_target: next_target(targets.drop(allocations.size), cash)
    }
  end

  private

  def next_target(remaining, cash)
    entry = remaining.first
    return nil if entry.nil?

    cost = entry.estimated_total_paise / 100.0
    shortfall = [(cost - cash), 0.0].max.round(2)
    {
      settlement_case_id: entry.settlement_case.id,
      name: entry.debt_account.name,
      lender: entry.debt_account.lender,
      settlement_cost: cost.round(2),
      shortfall: shortfall,
      months_to_fund: months_to_fund(shortfall)
    }
  end

  def months_to_fund(shortfall)
    return 0 if shortfall.zero?

    allocation = SettlementCapitalService.new(@user).call[:settlement_allocation]
    return nil if allocation <= 0

    (shortfall / allocation).ceil
  end
end
