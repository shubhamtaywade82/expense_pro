class CreateCreditCards < ActiveRecord::Migration[7.1]
  def change
    create_table :credit_cards do |t|
      t.string :name
      t.string :card_type
      t.date :expiry_date
      t.date :statement_date
      t.date :payment_due_date
      t.boolean :reminder
      t.string :last_four_digits
      t.text :description
      t.text :additional_notes
      t.boolean :has_annual_fee
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
