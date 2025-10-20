# frozen_string_literal: true

# CardEmiPlan captures credit-card-to-EMI conversions and their repayment progress.
class CardEmiPlan < ApplicationRecord
  belongs_to :account
  has_many :repayment_schedules, as: :source, dependent: :destroy

  validates :due_day_of_month, inclusion: { in: 1..31 }, allow_nil: true
  validates :principal, :emi, :paid_amount, :remaining_amount,
            numericality: { greater_than_or_equal_to: 0 }
end
