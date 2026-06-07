class CreateExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :expenses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.string :description
      t.date :expense_date, null: false
      t.string :payment_method, null: false, default: "cash"
      t.boolean :is_recurring, null: false, default: false

      t.timestamps
    end

    add_index :expenses, [ :user_id, :expense_date ]
  end
end
