class ChangeTransactionsNulls < ActiveRecord::Migration[8.0]
  def change
    change_column_null :transactions, :category_id, true
    change_column_null :transactions, :loan_account_id, true
    change_column_null :transactions, :taggable_type, true
    change_column_null :transactions, :taggable_id, true
  end
end
