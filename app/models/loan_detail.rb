# frozen_string_literal: true

# LoanDetail stores attributes that are unique to amortising loans.
class LoanDetail < ApplicationRecord
  belongs_to :account

  validates :due_day_of_month, inclusion: { in: 1..31 }, allow_nil: true
  validates :principal, :outstanding, :paid_amount,
            :remaining_amount, :total_interest_paid,
            numericality: { greater_than_or_equal_to: 0 }
end
