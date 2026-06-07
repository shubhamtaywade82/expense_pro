class CreateLoans < ActiveRecord::Migration[8.0]
  def change
    create_table :loans do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.string :name, null: false
      t.string :lender
      t.decimal :principal_amount, precision: 14, scale: 2, null: false
      t.decimal :interest_rate, precision: 6, scale: 3, null: false
      t.integer :tenure_months, null: false
      t.date :start_date, null: false
      t.string :loan_type, null: false, default: "personal"
      t.text :notes

      t.timestamps
    end
  end
end
