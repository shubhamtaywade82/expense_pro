class AddEmploymentToIncomes < ActiveRecord::Migration[8.0]
  def change
    add_reference :incomes, :employment, null: true, foreign_key: true
  end
end
