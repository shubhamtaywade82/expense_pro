class Expense < ApplicationRecord
  belongs_to :user
  belongs_to :credit_card, optional: true

  validates :category, presence: true
  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_method, presence: true
  validates :expense_type, presence: true, inclusion: { in: %w[fixed variable periodic unforeseen] }
  validates :payment_type, presence: true, inclusion: { in: %w[cash debit_card credit_card] }

  before_save :create_transaction_if_credit_card

  private

  def create_transaction_if_credit_card
    return unless payment_type == "credit_card" && credit_card_id.present?

    Transaction.create!(
      credit_card_id:,
      amount:,
      category:,
      date:,
      notes: description
    )
  end
end
