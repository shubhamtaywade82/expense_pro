class CreateMonthlyBills < ActiveRecord::Migration[8.0]
  def change
    create_table :monthly_bills do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.integer :due_date, null: false
      t.integer :reminder_days, null: false, default: 3
      t.text :notes
      t.boolean :is_paid, null: false, default: false
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    add_index :monthly_bills, [ :user_id, :is_active ]
  end
end
