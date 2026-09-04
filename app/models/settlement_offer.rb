# frozen_string_literal: true

# A concrete offer on the table: creditor claim settled at a percentage,
# with the fee/GST breakdown recomputed from the case's terms on save.
# The claim amount never becomes the settlement amount by itself — only
# offers carry the negotiated numbers.
class SettlementOffer < ApplicationRecord
  has_paper_trail

  belongs_to :settlement_case

  validates :settlement_percentage,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :offered_on, presence: true

  enum :status, { proposed: 0, countered: 1, accepted: 2, rejected: 3, expired: 4 }

  monetize :claim_amount_paise, as: :claim_amount, numericality: { greater_than: 0 }
  monetize :settlement_amount_paise, as: :settlement_amount
  monetize :service_fee_paise, as: :service_fee
  monetize :gst_paise, as: :gst
  monetize :total_amount_paise, as: :total_amount

  before_validation :recompute_amounts

  scope :active, -> { where(status: %i[proposed countered]) }
  scope :accepted, -> { where(status: :accepted) }

  def accept!
    update!(status: :accepted, accepted_on: Date.current)
  end

  def expired?
    return false if valid_until.nil?

    valid_until < Date.current && status.in?(%w[proposed countered])
  end

  private

  # Single source of truth for the money math is SettlementCalculator;
  # offers persist its output so history stays frozen even if the case's
  # fee terms change later.
  def recompute_amounts
    return if claim_amount_paise.blank?

    result = SettlementCalculator.call(
      claim_paise: claim_amount_paise,
      settlement_percentage: settlement_percentage || 0,
      service_fee_percentage: settlement_case.service_fee_percentage,
      gst_percentage: settlement_case.gst_percentage
    )

    self.settlement_amount_paise = result[:settlement_amount_paise]
    self.service_fee_paise = result[:service_fee_paise]
    self.gst_paise = result[:gst_paise]
    self.total_amount_paise = result[:total_paise]
  end
end
