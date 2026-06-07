class AddIsReceivedToIncomes < ActiveRecord::Migration[8.0]
  def change
    add_column :incomes, :is_received, :boolean
  end
end
