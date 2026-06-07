class AddEndDateToIncomes < ActiveRecord::Migration[8.0]
  def change
    add_column :incomes, :end_date, :date
  end
end
