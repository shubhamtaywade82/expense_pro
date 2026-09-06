# frozen_string_literal: true

class AddTrackerFieldsToDebtAccounts < ActiveRecord::Migration[8.0]
  def change
    change_table :debt_accounts, bulk: true do |t|
      t.bigint :credit_limit_paise, default: 0, null: false
      t.bigint :overdue_amount_paise, default: 0, null: false
      t.integer :statement_day
      t.integer :due_day
      t.integer :tenure_months
      t.integer :remaining_tenure_months
      t.string :bureau_status
    end
  end
end
