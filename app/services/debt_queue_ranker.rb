# frozen_string_literal: true

# Orders the settlement pipeline: which account should be targeted next?
#
# Stage rules (default strategy from the clearance plan):
#   1. legal_opportunity — formal notice received or active negotiation
#   2. small_balance     — claim <= ₹25,000   (quick wins)
#   3. medium_balance    — claim <= ₹1,00,000
#   4. large_unsecured   — claim > ₹1,00,000
#
# Within a stage, a transparent 0-100 score ranks cases:
#   readiness (30) + cash required (20) + debt size (15)
#     + cashflow impact (15) + legal status (15) + account age (5)
#
# The ranker is read-only: it returns stage/score per case and never
# writes, so it is safe to call on every dashboard render.
class DebtQueueRanker
  STAGE_SMALL_BALANCE_PAISE = 2_500_000    # ₹25,000.00
  STAGE_MEDIUM_BALANCE_PAISE = 10_000_000  # ₹1,00,000.00

  NEGOTIATION_STATUSES = %w[negotiation offer_received agreed paying].freeze

  Entry = Struct.new(
    :settlement_case, :debt_account, :stage, :score, :breakdown,
    :estimated_total_paise, :min_total_paise, :funding_progress, :eligible, keyword_init: true
  )

  def initialize(user)
    @user = user
  end

  def call
    cases = @user.settlement_cases.open.includes(:debt_account, :settlement_contributions, :settlement_payments)
    entries = cases.map { |c| entry_for(c) }
    entries.sort_by { |e| [e.stage, -e.score, -e.settlement_case.priority_before_type_cast] }
  end

  # Stage for a case that is not yet ranked (e.g. right after creation).
  def stage_for(settlement_case)
    claim = settlement_case.current_claim_paise
    if formal_opportunity?(settlement_case)
      :legal_opportunity
    elsif claim <= STAGE_SMALL_BALANCE_PAISE
      :small_balance
    elsif claim <= STAGE_MEDIUM_BALANCE_PAISE
      :medium_balance
    else
      :large_unsecured
    end
  end

  private

  def entry_for(settlement_case)
    claim = settlement_case.current_claim_paise
    total_max = settlement_case.estimated_total
    total_min = settlement_case.estimated_total(percentage: settlement_case.target_min_percentage)
    obligation = settlement_case.debt_account.monthly_cashflow_demand

    stage = stage_for(settlement_case)
    breakdown = {
      readiness: readiness_score(settlement_case),
      cash_required: cash_required_score(total_max),
      debt_size: debt_size_score(claim),
      cashflow_impact: cashflow_impact_score(claim, obligation),
      legal_status: legal_status_score(settlement_case),
      account_age: account_age_score(settlement_case)
    }

    Entry.new(
      settlement_case: settlement_case,
      debt_account: settlement_case.debt_account,
      stage: stage,
      score: breakdown.values.sum.round(1),
      breakdown: breakdown,
      estimated_total_paise: total_max,
      min_total_paise: total_min,
      funding_progress: settlement_case.funding_progress,
      eligible: settlement_case.eligible?
    )
  end

  def formal_opportunity?(case_record)
    case_record.debt_account.formal_notice? || NEGOTIATION_STATUSES.include?(case_record.status)
  end

  # Share of the projected cost already saved.
  def readiness_score(case_record)
    (case_record.funding_progress / 100.0 * 30).round(1)
  end

  # Cheaper settlements score higher, relative to the most expensive case.
  def cash_required_score(total_paise)
    max_total = [@max_total ||= @user.settlement_cases.open.sum { |c| c.estimated_total }, 1].max
    (20 * (1.0 - [total_paise.to_f / max_total, 1.0].min)).round(1)
  end

  def debt_size_score(claim_paise)
    max_claim = [@max_claim ||= @user.settlement_cases.open.maximum(:current_claim_paise) || 0, 1].max
    (15 * (1.0 - [claim_paise.to_f / max_claim, 1.0].min)).round(1)
  end

  def cashflow_impact_score(claim_paise, monthly_obligation)
    max_claim = [@max_claim ||= @user.settlement_cases.open.maximum(:current_claim_paise) || 0, 1].max
    ratio = claim_paise.positive? ? monthly_obligation.to_f / max_claim : 0.0
    (15 * [ratio, 1.0].min).round(1)
  end

  def legal_status_score(case_record)
    formal_opportunity?(case_record) ? 15.0 : 0.0
  end

  def account_age_score(case_record)
    months = case_record.debt_account.age_in_months
    (5 * [months / 24.0, 1.0].min).round(1)
  end
end
