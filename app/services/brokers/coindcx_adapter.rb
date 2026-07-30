module Brokers
  class CoinDCXAdapter < BaseAdapter
    BASE_URL = "https://api.coindcx.com"

    def broker_key
      "coindcx"
    end

    def broker_name
      "CoinDCX"
    end

    def profile
      api_get("/exchange/v1/users/me")
    end

    def positions
      api_post("/exchange/v1/positions")
    end

    def holdings
      api_post("/exchange/v1/balances")
    end

    def orders
      api_post("/exchange/v1/orders", status: "open")
    end

    def trade_book
      []
    end

    def trade_history(from_date:, to_date:, page: 0)
      data = api_post("/exchange/v1/trade_history", page: page)
      data.map { |t| normalize_dcx_trade(t) }
    end

    def trade_history_all(from_date:, to_date:)
      trades = []
      truncated = false

      50.times do |page|
        page_trades = trade_history(from_date: from_date, to_date: to_date, page: page)
        break if page_trades.empty?

        trades.concat(page_trades)
        truncated = true if page == 49
      end

      { trades: trades, truncated: truncated }
    end

    def fund_limits
      api_post("/exchange/v1/balances")
    end

    def ledger(from_date:, to_date:)
      api_post("/exchange/v1/trade_history", from: from_date, to: to_date)
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
      raise "CoinDCX not configured" unless token

      query = params.any? ? "?#{params.to_query}" : ""
      response = HTTParty.get("#{BASE_URL}#{path}#{query}",
        headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" },
        timeout: 15
      )
      response.success? ? response.parsed_response : []
    rescue StandardError => e
      Rails.logger.warn("[CoinDCXAdapter] GET #{path} failed: #{e.message}")
      []
    end

    def api_post(path, body = {})
      token = current_token!
      raise "CoinDCX not configured" unless token

      response = HTTParty.post("#{BASE_URL}#{path}",
        headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" },
        body: body.to_json,
        timeout: 15
      )
      response.success? ? response.parsed_response : []
    rescue StandardError => e
      Rails.logger.warn("[CoinDCXAdapter] POST #{path} failed: #{e.message}")
      []
    end

    def current_token!
      stored = BrokerAccessToken.active(Current.user, broker: broker_key)
      return stored.access_token if stored

      credential = BrokerCredential.find_by(user: Current.user, broker: broker_key)
      raise "CoinDCX API key not configured" unless credential&.client_id.present? && credential&.fallback_access_token.present?

      BrokerAccessToken.create!(
        user: Current.user,
        broker: broker_key,
        access_token: credential.fallback_access_token,
        expires_at: 365.days.from_now
      ).access_token
    end

    def normalize_dcx_trade(raw)
      {
        exchange_trade_id: raw["id"].to_s,
        transaction_type: raw["side"].to_s.upcase,
        exchange_segment: "dcx_crypto",
        trading_symbol: raw["market"].to_s,
        security_id: raw["market"].to_s,
        quantity: raw["quantity"].to_f,
        price: raw["price"].to_f,
        trade_date: raw["created_at"],
        brokerage: raw["fee"].to_f,
        stt: 0.0,
        gst: 0.0,
        sebi_tax: 0.0,
        exchange_charges: 0.0,
        stamp_duty: 0.0,
        product_type: "CNC",
        order_type: raw["order_type"].to_s,
        instrument: "EQUITY",
        isin: nil,
        expiry_date: nil,
        option_type: nil,
        strike_price: nil,
        raw_data: raw
      }
    end
  end
end
