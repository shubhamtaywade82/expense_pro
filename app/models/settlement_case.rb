# frozen_string_literal: true

# One settlement process against one DebtAccount. Holds the negotiated
# terms (target range, service fee %, GST %), the funding plan and the
# pipeline state. The state machine:
#
#   drafting -> funding -> negotiation -> offer_received -> agreed
#            -> paying -> settled -> closed   (stalled from anywhere)
class SettlementCase < ApplicationRecord
  has_paper_trail

  belongs_to :user
  belongs_to :debt_account

  has_many :settlement_offers, dependent: :destroy
  has_many :settlement_contributions, dependent: :destroy
  has_many :settlement_payments, dependent: :destroy
  has_many :settlement_documents, dependent: :destroy

  validates :started_on, presence: true
  validates :target_min_percentage, :target_max_percentage,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :eligibility_threshold_percentage,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate  :target_range_is_sane

  enum :status, {
    drafting: 0, funding: 1, negotiation: 2, offer_received: 3,
    agreed: 4, paying: 5, settled: 6, closed: 7, stalled: 8
  }

  # Queue stages (see DebtQueueRanker): 1 = formal/legal opportunity,
  # 2 = very small balances, 3 = medium, 4 = large unsecured.
  enum :stage, { legal_opportunity: 1, small_balance: 2, medium_balance: 3, large_unsecured: 4 }

  enum :priority, { low: 0, normal: 1, high: 2, critical: 3 }

  monetize :original_claim_paise, as: :original_claim, numericality: { greater_than_or_equal_to: 0 }
  monetize :current_claim_paise, as: :current_claim, numericality: { greater_than_or_equal_to: 0 }
  monetize :monthly_contribution_paise, as: :monthly_contribution,
           numericality: { greater_than_or_equal_to: 0 }

  scope :open, -> { where.not(status: %i[settled closed]) }
  scope :in_pipeline_order, -> { order(:stage, :priority, :current_claim_paise) }

  # Estimated all-in cost at a given settlement percentage (Freed formula:
  # settlement + service fee on claim + GST on fee).
  def estimated_total(percentage: target_max_percentage)
    SettlementCalculator.call(
      claim_paise: current_claim_paise,
      settlement_percentage: percentage,
      service_fee_percentage: service_fee_percentage,
      gst_percentage: gst_percentage
    )[:total_paise]
  end

  def estimated_total_range
    { min: estimated_total(percentage: target_min_percentage),
      max: estimated_total(percentage: target_max_percentage) }
  end

  # Total money set aside for this case so far.
  def contributed_amount_paise
    settlement_contributions.sum(:amount_paise)
  end

  # Money still needed to be saved: contributions minus what was already
  # paid out for the settlement itself.
  def settlement_fund_paise
    contributed_amount_paise - settlement_payments.sum(:total_paid_paise)
  end

  def funding_progress
    target = estimated_total
    return 0.0 if target.zero?

    ((settlement_fund_paise.to_f / target) * 100).round(1).clamp(0.0, 100.0)
  end

  # Freed-style funding gate: a share of the projected cost must be saved
  # before negotiation starts in earnest.
  def eligible?
    settlement_fund_paise >= estimated_total * eligibility_threshold_percentage / 100
  end

  def offer_received!(offer)
    update!(status: :offer_received) if may_receive_offer?
  end

  def may_receive_offer?
    %w[funding negotiation offer_received].include?(status)
  end

  def mark_settled!(closed_on: Date.current)
    transaction do
      update!(status: :settled, closed_on: closed_on)
      debt_account.update!(status: :settled, current_balance_paise: 0)
    end
  end

  private

  def target_range_is_sane
    return if target_min_percentage.nil? || target_max_percentage.nil?

    errors.add(:target_max_percentage, "must be >= target min percentage") if target_max_percentage < target_min_percentage
  end
end
