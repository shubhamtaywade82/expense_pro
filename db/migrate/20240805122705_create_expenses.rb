class CreateExpenses < ActiveRecord::Migration[7.1]
  def change
    create_table :expenses do |t|
      t.string :category
      t.text :description
      t.decimal :amount
      t.string :payment_method
      t.string :expense_type
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
