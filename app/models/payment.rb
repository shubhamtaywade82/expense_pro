# frozen_string_literal: true

# Payment records how a specific repayment schedule entry was settled.
class Payment < ApplicationRecord
  enum method: { upi: 0, imps: 1, neft: 2, netbanking: 3, auto_debit: 4, cash: 5, other: 6 }

  belongs_to :repayment_schedule
  belongs_to :account

  validates :paid_on, presence: true
  validates :amount_paid, numericality: { greater_than_or_equal_to: 0 }
end
