class CreateTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :transactions do |t|
      t.references :credit_card, null: false, foreign_key: true
      t.decimal :amount
      t.string :category
      t.date :date
      t.text :notes

      t.timestamps
    end
  end
end
