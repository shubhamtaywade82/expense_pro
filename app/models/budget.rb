class Budget < ApplicationRecord
  has_paper_trail
  belongs_to :user
  belongs_to :category

  validates :amount, numericality: { greater_than: 0 }
  validates :alert_threshold, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :month, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  validates :year, numericality: { only_integer: true }
  validates :category_id, uniqueness: { scope: [ :user_id, :month, :year ] }

  scope :for_period, ->(month, year) { where(month: month, year: year) }

  def actual_spent
    spent = category.expenses.for_month(month, year).sum(:amount)

    if category.category_type == "bill"
      spent += category.monthly_bills.active.where(is_paid: true).sum(:amount)
    end

    spent
  end
end
