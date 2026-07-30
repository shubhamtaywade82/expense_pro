class LoanAccount < ApplicationRecord
  belongs_to :user
  has_many :emi_schedules, dependent: :destroy
  has_many :prepayments, dependent: :destroy

  validates :name, :lender, :loan_type, :principal_amount, :interest_rate, :tenure_months, :start_date, presence: true
end
