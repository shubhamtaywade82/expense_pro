class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.belongs_to :financial_account, null: false, foreign_key: true
      t.belongs_to :category, null: false, foreign_key: true
      t.belongs_to :loan_account, null: false, foreign_key: true
      t.references :taggable, polymorphic: true, null: false
      t.string :txn_type
      t.integer :status
      t.decimal :amount
      t.datetime :txn_date

      t.timestamps
    end
  end
end
