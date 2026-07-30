class Trade < ApplicationRecord
  TRANSACTION_TYPES = %w[BUY SELL].freeze
  EXCHANGE_SEGMENTS = %w[NSE_EQ NSE_FNO BSE_EQ BSE_FNO MCX_COMM].freeze
  PRODUCT_TYPES = %w[INTRADAY CNC MARGIN MTF CO BO].freeze
  ORDER_TYPES = %w[LIMIT MARKET STOP_LOSS STOP_LOSS_MARKET].freeze
  OPTION_TYPES = %w[CALL PUT].freeze
  INSTRUMENT_TYPES = %w[EQUITY DERIVATIVES].freeze

  belongs_to :user

  validates :transaction_type, inclusion: { in: TRANSACTION_TYPES }
  validates :exchange_segment, presence: true

  scope :for_broker, ->(broker) { where(broker: broker) }
  scope :for_period, ->(from, to) { where(trade_date: from..to) }
  scope :for_fy, ->(year) { where(trade_date: Date.new(year - 1, 4, 1)..Date.new(year, 3, 31)) }
  scope :buy, -> { where(transaction_type: "BUY") }
  scope :sell, -> { where(transaction_type: "SELL") }
  scope :recent_first, -> { order(trade_date: :desc, id: :desc) }
  scope :equity, -> { where(exchange_segment: %w[NSE_EQ BSE_EQ]) }
  scope :fno, -> { where(exchange_segment: %w[NSE_FNO BSE_FNO]) }
  scope :commodity, -> { where(exchange_segment: "MCX_COMM") }

  def buy?
    transaction_type == "BUY"
  end

  def sell?
    transaction_type == "SELL"
  end

  def derivative?
    instrument == "DERIVATIVES"
  end

  def equity?
    instrument == "EQUITY"
  end

  def total_value
    (traded_quantity.to_d * traded_price.to_d).round(2)
  end

  def total_charges
    [sebi_tax, stt, brokerage, gst, exchange_charges, stamp_duty].sum { |c| c.to_f }.round(2)
  end

  def net_value
    (total_value - total_charges).round(2)
  end

  def segment_key
    return "non_speculative_fo" if exchange_segment&.include?("FNO")
    return "commodity" if exchange_segment == "MCX_COMM"
    return "speculative_intraday" if equity? && product_type == "INTRADAY"
    return "equity_delivery" if equity? && product_type == "CNC"
    "other"
  end

  def display_symbol
    symbol = trading_symbol.presence || custom_symbol
    return symbol if symbol.present?

    parts = [strike_price, option_type, expiry_date].compact
    label = parts.size > 1 ? parts.map(&:to_s).join(" ") : parts.first.to_s
    label.present? ? label : "##{security_id}"
  end
end
