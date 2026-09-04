# frozen_string_literal: true

# Answers "how much money can actually go at my settlement debts?" by
# separating cash on hand from committed cash:
#
#   cash on hand − monthly essential commitments − emergency allocation
#     = settlement-capable cash
#
# Numbers come from the user's active IncomeScenario when one exists,
# and are otherwise derived from recorded income, bills and debts.
class SettlementCapitalService
  def initialize(user)
    @user = user
  end

  def call
    scenario = @user.income_scenarios.active.order(:effective_on).last

    {
      cash_on_hand: cash_on_hand,
      monthly_income: monthly_income(scenario),
      monthly_commitments: monthly_commitments(scenario),
      emergency_buffer: emergency_buffer(scenario),
      available_monthly_surplus: available_monthly_surplus(scenario),
      settlement_allocation: settlement_allocation(scenario),
      current_settlement_fund: current_settlement_fund,
      scenario_name: scenario&.name,
      projected_settlement_capital: projected_settlement_capital(scenario)
    }
  end

  private

  def cash_on_hand
    @cash_on_hand ||= @user.financial_accounts.sum(:balance).to_f
  end

  def monthly_income(scenario)
    return scenario.monthly_income.to_f if scenario

    last_month_total = @user.incomes.where(income_date: 1.month.ago.all_month).sum(:amount).to_f
    return last_month_total if last_month_total.positive?

    # Fall back to the monthly run-rate of recurring income templates.
    @user.incomes.templates.where(frequency: "monthly").sum(:amount).to_f
  end

  # What the month demands before any settlement saving: recurring bills
  # plus the monthly demand of every open debt account (EMIs for protected
  # loans, minimum dues / provisions for settlement accounts).
  def monthly_commitments(scenario)
    return scenario.monthly_commitments.to_f if scenario

    bills = @user.monthly_bills.active.sum(:amount).to_f
    debts = @user.debt_accounts.open.sum(&:monthly_cashflow_demand)
    bills + debts
  end

  def emergency_buffer(scenario)
    scenario ? scenario.buffer_allocation.to_f : 0.0
  end

  def available_monthly_surplus(scenario)
    [(monthly_income(scenario) - monthly_commitments(scenario) - emergency_buffer(scenario)), 0.0].max
  end

  def settlement_allocation(scenario)
    return scenario.settlement_allocation.to_f if scenario

    available_monthly_surplus(scenario)
  end

  # The settlement fund today: everything saved minus what was already
  # spent settling accounts.
  def current_settlement_fund
    (@user.settlement_contributions.sum(:amount_paise) -
      @user.settlement_payments.sum(:total_paid_paise)).to_f / 100
  end

  # Where the fund lands by the scenario's target date (or 12 months out):
  # current fund + monthly allocation + the scenario's named increments.
  def projected_settlement_capital(scenario)
    months = 12
    if scenario&.effective_on
      months = [(scenario.effective_on - Date.current).to_i / 30 + 1, 1].max
      months = 12 if months > 60
    end

    allocation = settlement_allocation(scenario)
    {
      months: months,
      amount: (current_settlement_fund + allocation * months).round(2)
    }
  end
end
