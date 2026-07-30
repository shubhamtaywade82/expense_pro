module Brokers
  class BaseAdapter
    NormalizedPortfolio = Data.define(:holdings, :positions)
    Holding = Data.define(:security_id, :trading_symbol, :exchange, :quantity, :average_price, :current_price, :pnl, :data)
    Position = Data.define(:security_id, :trading_symbol, :exchange, :net_quantity, :buy_average, :sell_average, :unrealized_pnl, :realized_pnl, :data)
    Trade = Data.define(
      :exchange_trade_id, :transaction_type, :exchange_segment, :trading_symbol,
      :security_id, :quantity, :price, :trade_date, :brokerage, :stt, :gst,
      :sebi_tax, :exchange_charges, :stamp_duty, :product_type, :order_type,
      :instrument, :isin, :expiry_date, :option_type, :strike_price, :raw_data
    )

    def broker_key
      raise NotImplementedError
    end

    def broker_name
      raise NotImplementedError
    end

    def profile
      raise NotImplementedError
    end

    def positions
      raise NotImplementedError
    end

    def holdings
      raise NotImplementedError
    end

    def orders
      raise NotImplementedError
    end

    def trade_book
      raise NotImplementedError
    end

    def trade_history(from_date:, to_date:, page: 0)
      raise NotImplementedError
    end

    def fund_limits
      raise NotImplementedError
    end

    def ledger(from_date:, to_date:)
      raise NotImplementedError
    end

    def segment_key(trade)
      raise NotImplementedError
    end

    def normalize_holding(raw)
      Holding.new(
        security_id: raw[:security_id].to_s,
        trading_symbol: raw[:trading_symbol].to_s,
        exchange: raw[:exchange].to_s,
        quantity: raw[:quantity].to_f,
        average_price: raw[:average_price].to_f,
        current_price: raw[:current_price].to_f,
        pnl: raw[:pnl].to_f,
        data: raw
      )
    end

    def normalize_position(raw)
      Position.new(
        security_id: raw[:security_id].to_s,
        trading_symbol: raw[:trading_symbol].to_s,
        exchange: raw[:exchange].to_s,
        net_quantity: raw[:net_quantity].to_f,
        buy_average: raw[:buy_average].to_f,
        sell_average: raw[:sell_average].to_f,
        unrealized_pnl: raw[:unrealized_pnl].to_f,
        realized_pnl: raw[:realized_pnl].to_f,
        data: raw
      )
    end

    def normalize_trade(raw)
      Trade.new(
        exchange_trade_id: raw[:exchange_trade_id].to_s,
        transaction_type: raw[:transaction_type].to_s,
        exchange_segment: raw[:exchange_segment].to_s,
        trading_symbol: raw[:trading_symbol].to_s,
        security_id: raw[:security_id].to_s,
        quantity: raw[:quantity].to_f,
        price: raw[:price].to_f,
        trade_date: raw[:trade_date],
        brokerage: raw[:brokerage].to_f,
        stt: raw[:stt].to_f,
        gst: raw[:gst].to_f,
        sebi_tax: raw[:sebi_tax].to_f,
        exchange_charges: raw[:exchange_charges].to_f,
        stamp_duty: raw[:stamp_duty].to_f,
        product_type: raw[:product_type].to_s,
        order_type: raw[:order_type].to_s,
        instrument: raw[:instrument].to_s,
        isin: raw[:isin].to_s,
        expiry_date: raw[:expiry_date],
        option_type: raw[:option_type].to_s,
        strike_price: raw[:strike_price].to_f,
        raw_data: raw
      )
    end

    def trade_attributes(normalized)
      {
        broker: broker_key,
        exchange_trade_id: normalized.exchange_trade_id,
        transaction_type: normalized.transaction_type,
        exchange_segment: normalized.exchange_segment,
        trading_symbol: normalized.trading_symbol,
        security_id: normalized.security_id,
        traded_quantity: normalized.quantity,
        traded_price: normalized.price,
        trade_date: normalized.trade_date,
        brokerage: normalized.brokerage,
        stt: normalized.stt,
        gst: normalized.gst,
        sebi_tax: normalized.sebi_tax,
        exchange_charges: normalized.exchange_charges,
        stamp_duty: normalized.stamp_duty,
        product_type: normalized.product_type,
        order_type: normalized.order_type,
        instrument: normalized.instrument,
        isin: normalized.isin,
        expiry_date: normalized.expiry_date,
        option_type: normalized.option_type,
        strike_price: normalized.strike_price,
        raw_data: normalized.raw_data
      }
    end

    def import_key(segment, from_date:, to_date:)
      "#{broker_key}:#{segment}:#{from_date}:#{to_date}"
    end

    def display_name(segment, from_date:, to_date:)
      "#{broker_name} #{segment} (#{from_date} to #{to_date})"
    end
  end
end
