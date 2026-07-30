class CreateTaxDeductions < ActiveRecord::Migration[8.0]
  def change
    create_table :tax_deductions do |t|
      t.references :income, null: false, foreign_key: true
      t.string :deduction_type, null: false
      t.decimal :tds_amount, precision: 12, scale: 2, null: false
      t.date :paid_on
      t.string :remarks

      t.timestamps
    end

    add_index :tax_deductions, [:income_id, :deduction_type]
  end
end
