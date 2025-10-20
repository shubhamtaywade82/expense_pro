# frozen_string_literal: true

# Statement represents a billing cycle snapshot for a credit card account.
class Statement < ApplicationRecord
  belongs_to :account
  has_many :card_transactions, dependent: :destroy
  has_one :repayment_schedule, as: :source, dependent: :destroy

  validates :statement_balance, :min_due, :fees_and_interest,
            numericality: { greater_than_or_equal_to: 0 }
end
