class CreatePrepayments < ActiveRecord::Migration[8.0]
  def change
    create_table :prepayments do |t|
      t.references :loan_account, null: false, foreign_key: true
      t.decimal :amount, precision: 15, scale: 2
      t.date :date
      t.string :impact

      t.timestamps
    end
  end
end
