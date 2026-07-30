class CreateTrades < ActiveRecord::Migration[8.0]
  def change
    create_table :trades do |t|
      t.references :user, null: false, foreign_key: true
      t.string :broker, null: false, default: "dhan"

      # Identifiers
      t.string :exchange_trade_id
      t.string :order_id
      t.string :exchange_order_id
      t.string :dhan_client_id

      # Trade details
      t.string :transaction_type, null: false # BUY / SELL
      t.string :exchange_segment, null: false  # NSE_EQ / NSE_FNO / MCX_COMM
      t.string :product_type                   # INTRADAY / CNC / MARGIN
      t.string :order_type                     # LIMIT / MARKET / STOP_LOSS
      t.string :trading_symbol
      t.string :custom_symbol
      t.string :security_id
      t.string :isin
      t.string :instrument                     # EQUITY / DERIVATIVES

      t.decimal :traded_quantity, precision: 14, scale: 4
      t.decimal :traded_price, precision: 14, scale: 2

      # F&O fields
      t.date :expiry_date
      t.string :option_type                    # CALL / PUT
      t.decimal :strike_price, precision: 14, scale: 2

      # Charges (as reported by broker)
      t.decimal :sebi_tax, precision: 12, scale: 2, default: 0.0
      t.decimal :stt, precision: 12, scale: 2, default: 0.0
      t.decimal :brokerage, precision: 12, scale: 2, default: 0.0
      t.decimal :gst, precision: 12, scale: 2, default: 0.0
      t.decimal :exchange_charges, precision: 12, scale: 2, default: 0.0
      t.decimal :stamp_duty, precision: 12, scale: 2, default: 0.0

      # Raw broker data (preserve original response for audit)
      t.jsonb :raw_data, default: {}

      t.datetime :trade_date
      t.datetime :exchange_time
      t.timestamps
    end

    add_index :trades, %i[user_id broker trade_date]
    add_index :trades, %i[user_id exchange_trade_id], unique: true, where: "exchange_trade_id IS NOT NULL"
    add_index :trades, %i[user_id exchange_segment]
  end
end
