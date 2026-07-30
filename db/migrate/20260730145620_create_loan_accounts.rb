class CreateLoanAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :loan_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :lender
      t.string :loan_type
      t.decimal :principal_amount, precision: 15, scale: 2
      t.decimal :interest_rate, precision: 5, scale: 2
      t.integer :tenure_months
      t.decimal :emi_amount, precision: 15, scale: 2
      t.date :start_date
      t.string :status
      t.decimal :outstanding_principal, precision: 15, scale: 2

      t.timestamps
    end
  end
end
