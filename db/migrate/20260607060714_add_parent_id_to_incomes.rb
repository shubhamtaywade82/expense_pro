class AddParentIdToIncomes < ActiveRecord::Migration[8.0]
  def change
    add_column :incomes, :parent_id, :bigint
    add_index :incomes, :parent_id
  end
end
