class CreateIncomes < ActiveRecord::Migration[8.0]
  def change
    create_table :incomes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :source, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.date :income_date, null: false
      t.boolean :is_recurring, null: false, default: false
      t.string :frequency, null: false, default: "monthly"
      t.text :notes

      t.timestamps
    end

    add_index :incomes, [ :user_id, :income_date ]
  end
end
