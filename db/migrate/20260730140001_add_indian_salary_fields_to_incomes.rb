class AddIndianSalaryFieldsToIncomes < ActiveRecord::Migration[8.0]
  def change
    add_column :incomes, :income_type, :string, default: "salary", null: false
    add_column :incomes, :gross_amount, :decimal, precision: 14, scale: 2
    add_column :incomes, :tax_deducted, :decimal, precision: 14, scale: 2, default: 0.0
    add_column :incomes, :pf_deducted, :decimal, precision: 14, scale: 2, default: 0.0
    add_column :incomes, :other_deductions, :decimal, precision: 14, scale: 2, default: 0.0
    add_column :incomes, :metadata, :jsonb, default: {}
    
    add_index :incomes, :income_type
  end
end
