class Loan < ApplicationRecord
  has_paper_trail
  TYPES = %w[home car personal education business gold other].freeze

  belongs_to :user
  belongs_to :category
  has_many :emi_payments, -> { order(:emi_number) }, dependent: :destroy, inverse_of: :loan

  validates :name, presence: true
  validates :principal_amount, numericality: { greater_than: 0 }
  validates :interest_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :tenure_months, numericality: { only_integer: true, greater_than: 0 }
  validates :start_date, presence: true
  validates :loan_type, inclusion: { in: TYPES }

  after_create :generate_emi_schedule

  # Standard reducing-balance EMI formula:
  #   EMI = P * r * (1 + r)^n / ((1 + r)^n - 1)
  # where r is the monthly interest rate and n is the tenure in months.
  def emi_amount
    p = principal_amount.to_d
    r = (interest_rate.to_d / 100) / 12
    n = tenure_months

    return (p / n).round(2) if r.zero?

    factor = (1 + r) ** n
    (p * r * factor / (factor - 1)).round(2)
  end

  def outstanding_principal
    paid_emi_sum = if emi_payments.loaded?
      emi_payments.select(&:is_paid).sum(&:principal_amount)
    else
      emi_payments.where(is_paid: true).sum(:principal_amount)
    end
    principal_amount.to_d - paid_emi_sum
  end

  class << self
    # One set of grouped queries for every loan's paid-count/interest/
    # outstanding-principal, instead of each loan loading (or worse,
    # re-querying) its own emi_payments collection. Returns
    # { loan => { paid_count:, total_interest:, outstanding_principal: } }.
    def batch_aggregates(loans)
      loan_ids = loans.map(&:id)
      paid_counts = EmiPayment.where(loan_id: loan_ids, is_paid: true).group(:loan_id).count
      total_interests = EmiPayment.where(loan_id: loan_ids).group(:loan_id).sum(:interest_amount)
      paid_principals = EmiPayment.where(loan_id: loan_ids, is_paid: true).group(:loan_id).sum(:principal_amount)

      loans.index_with do |loan|
        {
          paid_count: paid_counts[loan.id] || 0,
          total_interest: total_interests[loan.id] || 0,
          outstanding_principal: loan.principal_amount.to_d - (paid_principals[loan.id] || 0).to_d
        }
      end
    end
  end

  private

  # Pre-calculates and persists the full amortization schedule so that EMI
  # amounts and the principal/interest split never change after the loan is created.
  def generate_emi_schedule
    balance = principal_amount.to_d
    monthly_rate = (interest_rate.to_d / 100) / 12
    emi = emi_amount

    tenure_months.times do |index|
      interest_component = (balance * monthly_rate).round(2)
      principal_component = (emi - interest_component).round(2)
      principal_component = balance if index == tenure_months - 1

      emi_payments.create!(
        user: user,
        emi_number: index + 1,
        due_date: start_date.advance(months: index + 1),
        amount: (principal_component + interest_component).round(2),
        principal_amount: principal_component,
        interest_amount: interest_component,
        is_paid: false
      )

      balance -= principal_component
    end
  end
end
