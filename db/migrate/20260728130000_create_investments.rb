class CreateInvestments < ActiveRecord::Migration[8.0]
  def change
    create_table :investments do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :asset_class, null: false, default: "long_term_equity" # speculative_intraday, non_speculative_fo, swing_trading, long_term_equity, mutual_funds, fixed_income, crypto, elss_80c, gold
      t.string :symbol
      t.decimal :quantity, precision: 14, scale: 4, default: 1.0, null: false
      t.decimal :buy_price, precision: 14, scale: 2, null: false
      t.decimal :current_price, precision: 14, scale: 2
      t.decimal :sell_price, precision: 14, scale: 2
      t.decimal :invested_amount, precision: 14, scale: 2, null: false
      t.decimal :realized_pnl, precision: 14, scale: 2, default: 0.0, null: false
      t.decimal :unrealized_pnl, precision: 14, scale: 2, default: 0.0, null: false
      t.date :purchase_date, null: false
      t.date :sell_date
      t.string :status, null: false, default: "active" # active, realized
      t.text :notes

      t.timestamps
    end

    add_index :investments, [:user_id, :asset_class]
    add_index :investments, [:user_id, :status]
  end
end
