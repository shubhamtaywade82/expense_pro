class ChangeIsReceivedDefaultInIncomes < ActiveRecord::Migration[8.0]
  def change
    change_column_default :incomes, :is_received, from: nil, to: true
    Income.update_all(is_received: true)
  end
end
