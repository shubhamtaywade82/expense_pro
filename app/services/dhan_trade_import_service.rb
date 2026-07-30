class DhanTradeImportService
  BROKER = "dhan"

  CHARGE_MAP = {
    sebi_tax: :sebi_tax,
    stt: :stt,
    brokerage_charges: :brokerage,
    service_tax: :gst,
    exchange_transaction_charges: :exchange_charges,
    stamp_duty: :stamp_duty
  }.freeze

  FIELD_MAP = {
    dhan_client_id: :dhan_client_id,
    order_id: :order_id,
    exchange_order_id: :exchange_order_id,
    exchange_trade_id: :exchange_trade_id,
    transaction_type: :transaction_type,
    exchange_segment: :exchange_segment,
    product_type: :product_type,
    order_type: :order_type,
    trading_symbol: :trading_symbol,
    custom_symbol: :custom_symbol,
    security_id: :security_id,
    isin: :isin,
    instrument: :instrument,
    traded_quantity: :traded_quantity,
    traded_price: :traded_price,
    drv_expiry_date: :expiry_date,
    drv_option_type: :option_type,
    drv_strike_price: :strike_price,
    create_time: :trade_date,
    exchange_time: :exchange_time
  }.freeze

  def initialize(user, trades)
    @user = user
    @trades = trades
  end

  def call
    imported = 0

    @trades.each do |raw|
      attrs = map_attributes(raw)
      next unless attrs[:exchange_trade_id].present?

      trade = @user.trades.find_or_initialize_by(
        broker: BROKER,
        exchange_trade_id: attrs[:exchange_trade_id]
      )

      trade.assign_attributes(attrs)
      trade.raw_data = raw if trade.new_record? || trade.changed?
      trade.save! if trade.new_record? || trade.changed?
      imported += 1
    end

    imported
  end

  private

  def map_attributes(raw)
    attrs = { broker: BROKER }

    FIELD_MAP.each do |from, to|
      attrs[to] = raw[from.to_s] || raw[from]
    end

    attrs[:trade_date] = parse_time(raw, :create_time)
    attrs[:exchange_time] = parse_time(raw, :exchange_time)

    CHARGE_MAP.each do |from, to|
      attrs[to] = raw[from.to_s].to_f
    end

    attrs
  end

  def parse_time(raw, key)
    val = raw[key.to_s] || raw[key]
    val.present? ? Time.parse(val.to_s) : nil
  rescue StandardError
    nil
  end
end
