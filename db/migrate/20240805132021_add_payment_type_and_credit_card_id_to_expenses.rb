class AddPaymentTypeAndCreditCardIdToExpenses < ActiveRecord::Migration[7.1]
  def change
    add_column :expenses, :payment_type, :string
    add_reference :expenses, :credit_card, null: false, foreign_key: true
  end
end
