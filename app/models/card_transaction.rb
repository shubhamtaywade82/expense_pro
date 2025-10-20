# frozen_string_literal: true

# CardTransaction stores individual line items from a credit card statement.
class CardTransaction < ApplicationRecord
  belongs_to :account
  belongs_to :statement, optional: true

  validates :posted_on, presence: true
  validates :amount, numericality: true
end
