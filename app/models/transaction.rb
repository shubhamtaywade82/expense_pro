class Transaction < ApplicationRecord
  belongs_to :credit_card

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :category, presence: true
  validates :date, presence: true
end
