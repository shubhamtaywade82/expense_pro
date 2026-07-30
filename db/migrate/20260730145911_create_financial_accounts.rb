class CreateFinancialAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :financial_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :account_name
      t.string :institution
      t.string :account_type
      t.decimal :balance, precision: 15, scale: 2
      t.datetime :last_synced_at

      t.timestamps
    end
  end
end
