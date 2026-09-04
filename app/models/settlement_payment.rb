# frozen_string_literal: true

# The real cash-out: creditor principal + platform service fee + GST.
# Created by SettlementPaymentService, which also advances the case
# state machine and (optionally) mirrors the outflow into the expense
# ledger so monthly reports stay complete.
class SettlementPayment < ApplicationRecord
  belongs_to :user
  belongs_to :settlement_case
  belongs_to :settlement_offer, optional: true

  validates :paid_on, presence: true

  monetize :settlement_amount_paise, as: :settlement_amount
  monetize :service_fee_paise, as: :service_fee
  monetize :gst_paise, as: :gst
  monetize :total_paid_paise, as: :total_paid

  scope :latest_first, -> { order(paid_on: :desc, id: :desc) }
end
