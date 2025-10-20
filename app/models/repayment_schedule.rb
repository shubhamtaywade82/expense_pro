# frozen_string_literal: true

# RepaymentSchedule represents a single due entry in the consolidated repayment calendar.
class RepaymentSchedule < ApplicationRecord
  enum amount_mode: { emi: 0, min_due: 1, fee: 2, other: 3 }
  enum status: { pending: 0, paid: 1, overdue: 2, waived: 3 }

  belongs_to :account
  belongs_to :source, polymorphic: true, optional: true
  has_many :payments, dependent: :restrict_with_error

  scope :due_between, ->(from, to) { where(due_on: from..to) }
  scope :pending_or_overdue, -> { where(status: %i[pending overdue]) }

  validates :due_on, presence: true
  validates :amount_due, numericality: { greater_than_or_equal_to: 0 }
end
