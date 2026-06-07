class Expense < ApplicationRecord
  PAYMENT_METHODS = %w[cash credit_card debit_card upi net_banking other].freeze

  belongs_to :user
  belongs_to :category

  validates :amount, numericality: { greater_than: 0 }
  validates :expense_date, presence: true
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }

  scope :for_month, ->(month, year) { where(expense_date: Date.new(year, month, 1)..Date.new(year, month, -1)) }
  scope :search, ->(term) { where("description ILIKE ?", "%#{sanitize_sql_like(term)}%") }
  scope :recent_first, -> { order(expense_date: :desc, id: :desc) }
end
