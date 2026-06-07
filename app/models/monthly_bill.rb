class MonthlyBill < ApplicationRecord
  belongs_to :user
  belongs_to :category

  validates :name, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :due_date, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 31 }
  validates :reminder_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:due_date) }

  def overdue?(today = Date.current)
    !is_paid && due_date < today.day
  end
end
