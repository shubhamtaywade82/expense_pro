class CreateBudgets < ActiveRecord::Migration[8.0]
  def change
    create_table :budgets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.integer :month, null: false
      t.integer :year, null: false
      t.decimal :amount, precision: 14, scale: 2, null: false
      t.integer :alert_threshold, null: false, default: 80

      t.timestamps
    end

    add_index :budgets, [ :user_id, :category_id, :month, :year ], unique: true, name: "index_budgets_on_user_category_month_year"
  end
end
