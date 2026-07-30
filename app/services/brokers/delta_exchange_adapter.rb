module Brokers
  class DeltaExchangeAdapter < BaseAdapter
    BASE_URL = "https://api.india.delta.exchange"
    MAINNET_URL = "https://api.delta.exchange"

    def broker_key
      "delta_exchange"
    end

    def broker_name
      "Delta Exchange India"
    end

    def profile
      api_get("/v2/user/profile")
    end

    def positions
      api_get("/v2/positions")
    end

    def holdings
      api_get("/v2/wallet/balances")
    end

    def orders
      api_get("/v2/orders", limit: 50)
    end

    def trade_book
      api_get("/v2/orders", limit: 50, state: "open")
    end

    def trade_history(from_date:, to_date:, page: 0)
      data = api_get("/v2/trades", limit: 100, offset: page * 100)
      data.map { |t| normalize_delta_trade(t) }
    end

    def trade_history_all(from_date:, to_date:)
      trades = []
      truncated = false

      20.times do |page|
        page_trades = trade_history(from_date: from_date, to_date: to_date, page: page)
        break if page_trades.empty?

        trades.concat(page_trades)
        truncated = true if page == 19
      end

      { trades: trades, truncated: truncated }
    end

    def fund_limits
      api_get("/v2/wallet/balances")
    end

    def ledger(from_date:, to_date:)
      api_get("/v2/wallet/transactions", start_date: from_date, end_date: to_date)
    end

    def segment_key(trade)
      "crypto"
    end

    def importable_segments
      %w[crypto]
    end

    def manual_asset_classes
      %w[crypto]
    end

    private

    def api_get(path, params = {})
      token = current_token!
      raise "Delta Exchange not configured" unless token

      query = params.any? ? "?#{params.to_query}" : ""
      response = HTTParty.get("#{BASE_URL}#{path}#{query}",
        headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" },
        timeout: 15
      )
      response.success? ? (response.parsed_response["result"] || response.parsed_response) : []
    rescue StandardError => e
      Rails.logger.warn("[DeltaExchangeAdapter] GET #{path} failed: #{e.message}")
      []
    end

    def current_token!
      stored = BrokerAccessToken.active(Current.user, broker: broker_key)
      return stored.access_token if stored

      credential = BrokerCredential.find_by(user: Current.user, broker: broker_key)
      raise "Delta Exchange API key not configured" unless credential&.client_id.present? && credential&.fallback_access_token.present?

      BrokerAccessToken.create!(
        user: Current.user,
        broker: broker_key,
        access_token: credential.fallback_access_token,
        expires_at: 365.days.from_now
      ).access_token
    end

    def normalize_delta_trade(raw)
      {
        exchange_trade_id: raw["id"].to_s,
        transaction_type: raw["side"].to_s.upcase,
        exchange_segment: "delta_crypto_derivatives",
        trading_symbol: raw["product_symbol"].to_s,
        security_id: raw["product_id"].to_s,
        quantity: raw["size"].to_f,
        price: raw["price"].to_f,
        trade_date: raw["created_at"],
        brokerage: raw["fee"].to_f,
        stt: 0.0,
        gst: 0.0,
        sebi_tax: 0.0,
        exchange_charges: 0.0,
        stamp_duty: 0.0,
        product_type: "MARGIN",
        order_type: raw["order_type"].to_s,
        instrument: raw["product_type"].to_s == "futures" ? "DERIVATIVES" : "EQUITY",
        isin: nil,
        expiry_date: raw["expires_at"],
        option_type: raw["option_type"].to_s,
        strike_price: raw["strike_price"].to_f,
        raw_data: raw
      }
    end
  end
end
