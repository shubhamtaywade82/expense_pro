class Expense < ApplicationRecord
  has_paper_trail
  PAYMENT_METHODS = %w[cash credit_card debit_card upi net_banking other].freeze

  belongs_to :user
  belongs_to :category

  validates :amount, numericality: { greater_than: 0 }
  validates :expense_date, presence: true
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }

  scope :for_month, ->(month, year) { where(expense_date: Date.new(year, month, 1)..Date.new(year, month, -1)) }
  scope :for_fy, ->(year) {
    y = year.to_i
    where(expense_date: Date.new(y - 1, 4, 1)..Date.new(y, 3, 31))
  }
  scope :search, ->(term) { where("description ILIKE ?", "%#{sanitize_sql_like(term)}%") }
  scope :recent_first, -> { order(expense_date: :desc, id: :desc) }
end
