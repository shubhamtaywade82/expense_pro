# frozen_string_literal: true

# Expense tracks discretionary spends outside of loan and credit card repayments.
class Expense < ApplicationRecord
  belongs_to :user

  scope :between, ->(from, to) { where(incurred_on: from..to) }

  validates :category, presence: true
  validates :incurred_on, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :notes, length: { maximum: 500 }, allow_blank: true
end
