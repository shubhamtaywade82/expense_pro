class AddCustomFieldsToIncomes < ActiveRecord::Migration[8.0]
  def change
    add_column :incomes, :is_custom, :boolean, default: false, null: false
    add_column :incomes, :change_reason, :string
    add_column :incomes, :original_amount, :decimal, precision: 14, scale: 2
  end
end
