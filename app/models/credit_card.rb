class CreditCard < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :destroy
  has_many :custom_fields, dependent: :destroy

  validates :name, presence: true
  validates :card_type, presence: true, inclusion: { in: %w[Visa MasterCard RuPay] }
  validates :expiry_date, presence: true
  validates :statement_date, presence: true
  validates :payment_due_date, presence: true
  validates :last_four_digits, presence: true, length: { is: 4 }

  def payment_status
    if Time.zone.today > payment_due_date
      "Overdue"
    else
      "Not settled"
    end
  end

  def closing_date
    statement_date.end_of_month
  end

  def next_closing_date
    closing_date + 1.month
  end

  def cutoff_date
    closing_date
  end

  def next_due_date
    payment_due_date + 1.month
  end
end
