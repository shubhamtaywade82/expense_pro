class EmiPayment < ApplicationRecord
  belongs_to :user
  belongs_to :loan, inverse_of: :emi_payments

  validates :emi_number, uniqueness: { scope: :loan_id }
  validates :amount, :principal_amount, :interest_amount, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:emi_number) }

  def mark_paid!(paid_on = Date.current)
    return false if is_paid?

    transaction do
      update!(is_paid: true, paid_date: paid_on)

      user.expenses.create!(
        category: loan.category,
        amount: amount,
        description: "EMI #{emi_number} — #{loan.name}",
        expense_date: paid_on,
        payment_method: "other",
        is_recurring: false
      )
    end
    true
  end
end
