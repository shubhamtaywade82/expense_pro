# frozen_string_literal: true

# Paper trail for a settlement case: creditor notices (e.g. Lok Adalat),
# offer letters, approvals, receipts, settlement letters and NOCs.
class SettlementDocument < ApplicationRecord
  belongs_to :user
  belongs_to :settlement_case

  has_one_attached :file

  enum :document_type, {
    creditor_notice: 0, settlement_offer_letter: 1, approval: 2,
    payment_receipt: 3, settlement_letter: 4, noc: 5, other: 6
  }

  enum :status, { pending: 0, received: 1, verified: 2 }

  validates :title, presence: true

  scope :for_type, ->(type) { where(document_type: type) }
end
