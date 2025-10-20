# frozen_string_literal: true

# CreditCardDetail stores the per-card lifecycle data that powers repayment summaries.
class CreditCardDetail < ApplicationRecord
  belongs_to :account

  validates :statement_day_of_month, :due_day_of_month,
            inclusion: { in: 1..31 }, allow_nil: true
  validates :outstanding, :bill_amount, :limit_amount,
            :utilization, :paid_amount, :remaining_due,
            numericality: { greater_than_or_equal_to: 0 }
end
