class CreateEmiSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :emi_schedules do |t|
      t.references :loan_account, null: false, foreign_key: true
      t.date :due_date
      t.integer :installment_number
      t.decimal :opening_balance, precision: 15, scale: 2
      t.decimal :emi_amount, precision: 15, scale: 2
      t.decimal :principal_component, precision: 15, scale: 2
      t.decimal :interest_component, precision: 15, scale: 2
      t.decimal :closing_balance, precision: 15, scale: 2
      t.string :status
      t.date :paid_on

      t.timestamps
    end
  end
end
