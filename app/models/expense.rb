class Expense < ApplicationRecord
  belongs_to :user

  validates :category, presence: true
  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_method, presence: true
  validates :expense_type, presence: true, inclusion: { in: %w[fixed variable periodic unforeseen] }
end
