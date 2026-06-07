class CreateEmiPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :emi_payments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :loan, null: false, foreign_key: true
      t.integer :emi_number, null: false
      t.date :due_date, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.decimal :principal_amount, precision: 14, scale: 2, null: false
      t.decimal :interest_amount, precision: 14, scale: 2, null: false
      t.boolean :is_paid, null: false, default: false
      t.date :paid_date

      t.timestamps
    end

    add_index :emi_payments, [ :loan_id, :emi_number ], unique: true
  end
end
