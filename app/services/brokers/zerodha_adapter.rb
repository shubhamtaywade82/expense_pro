module Brokers
  class ZerodhaAdapter < BaseAdapter
    BASE_URL = "https://api.kite.trade"

    def self.broker_type = "zerodha"
    def self.display_name = "Zerodha (Kite Connect)"
    def self.asset_classes = [:equity, :futures, :options, :mutual_funds]
    def self.auth_type = :api_key_secret  # api_key + api_secret + access_token (OAuth2)
    def self.required_credentials = [:api_key, :api_secret, :access_token]
    def self.rate_limit = { requests_per_second: 3, burst: 10 }
    def self.documentation_url = "https://kite.trade/docs/connect/v3/"

    def tax_category = :equity
    def tds_applicable? = false

    def authenticate!
      raw = get("/user/profile")
      raise AuthenticationError, "Invalid session" unless raw["status"] == "success"
      { success: true, account_info: raw["data"] }
    end

    def token_valid?
      authenticate![:success]
    rescue
      false
    end

    def refresh_token!
      # Zerodha: access_token expires daily — user must re-login via OAuth2
      # Cannot auto-refresh. Raise informative error.
      raise AuthenticationError,
        "Zerodha access token expires daily. Please re-authenticate via Kite Connect login flow."
    end

    def holdings
      raw = get("/portfolio/holdings")
      (raw["data"] || []).map do |h|
        NormalizedHolding.new(
          broker: "zerodha",
          symbol: h["tradingsymbol"],
          name: h["exchange"] == "NSE" ? h["tradingsymbol"] : h["tradingsymbol"],
          quantity: h["quantity"].to_f,
          avg_price: h["average_price"].to_f,
          current_price: h["last_price"].to_f,
          asset_class: "long_term_equity",
          raw_data: h
        )
      end
    end

    def positions
      raw = get("/portfolio/positions")
      (raw.dig("data", "net") || []).map do |p|
        NormalizedHolding.new(
          broker: "zerodha",
          symbol: p["tradingsymbol"],
          name: p["tradingsymbol"],
          quantity: p["quantity"].to_f,
          avg_price: p["average_price"].to_f,
          current_price: p["last_price"].to_f,
          asset_class: p["product"] == "MIS" ? "swing_trading" : "long_term_equity",
          raw_data: p
        )
      end
    end

    def trades(from_date:, to_date:)
      raw = get("/orders", params: { from: from_date.to_s, to: to_date.to_s })
      (raw["data"] || [])
        .select { |o| o["status"] == "COMPLETE" }
        .map { |o| normalize_trade(o) }
    end

    def trade_history_all(from_date:, to_date:, &progress_block)
      # Zerodha: /orders returns current day only
      # For history: /trades with date range (max 60 days per request)
      all_trades = []
      current = from_date

      while current <= to_date
        chunk_end = [current + 59.days, to_date].min
        @rate_limiter.throttle!

        raw = get("/trades", params: {
          from: current.to_s,
          to: chunk_end.to_s
        })

        (raw["data"] || []).each { |t| all_trades << normalize_trade(t) }
        progress_block&.call({ trades_fetched: all_trades.size, period: "#{current} to #{chunk_end}" })

        current = chunk_end + 1.day
      end

      all_trades
    end

    def fund_limits
      raw = get("/user/margins")
      raw["data"] || {}
    end

    def ledger(from_date:, to_date:)
      # Zerodha doesn't expose ledger via Kite API
      # Must use Console API or manual export
      raise APIError, "Ledger not available via Kite Connect API. Use Zerodha Console export."
    end

    def pnl_summary(from_date:, to_date:)
      # Zerodha: /portfolio/positions has day-wise and net P&L
      raw = get("/portfolio/positions")
      net = raw.dig("data", "net") || []
      {
        realized_pnl: net.sum { |p| p["realised"].to_f },
        unrealized_pnl: net.sum { |p| p["unrealised"].to_f },
        total_charges: net.sum { |p| p["charges"].to_f }
      }
    end

    private

    def get(path, params: {})
      @rate_limiter.throttle!
      response = connection.get(path, params)
      handle_response(response)
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.headers["Authorization"] = "token #{@credential.api_key}:#{@credential.access_token}"
        f.headers["X-Kite-Version"] = "3"
        f.options.timeout = 30
      end
    end

    def handle_response(response)
      body = JSON.parse(response.body) rescue {}
      case response.status
      when 200 then body
      when 401 then raise AuthenticationError, "Session expired — re-login required"
      when 403 then raise AuthenticationError, body["message"] || "Forbidden"
      when 429 then raise RateLimitError, "Rate limit exceeded"
      else raise APIError.new(body["message"] || "Kite API error", status: response.status)
      end
    end

    def normalize_trade(raw)
      NormalizedTrade.new(
        broker: "zerodha",
        exchange_trade_id: raw["trade_id"] || raw["order_id"],
        symbol: raw["tradingsymbol"],
        name: raw["tradingsymbol"],
        segment: map_zerodha_segment(raw),
        asset_class: map_zerodha_asset_class(raw),
        trade_type: raw["transaction_type"]&.downcase == "buy" ? :buy : :sell,
        quantity: raw["quantity"].to_f,
        price: raw["average_price"].to_f,
        amount: raw["quantity"].to_f * raw["average_price"].to_f,
        trade_date: raw["fill_timestamp"] ? Time.parse(raw["fill_timestamp"]).to_datetime : Date.current,
        charges: {
          brokerage: raw["charges"]&.dig("brokerage").to_f,
          stt: raw["charges"]&.dig("stt").to_f,
          exchange: raw["charges"]&.dig("exchange_turnover_charge").to_f,
          gst: raw["charges"]&.dig("gst").to_f,
          sebi: raw["charges"]&.dig("sebi_turnover_charge").to_f,
          stamp: raw["charges"]&.dig("stamp_duty").to_f
        },
        raw_data: raw
      )
    end

    def map_zerodha_segment(raw)
      case raw["exchange"]
      when "NSE", "BSE" then raw["product"] == "MIS" ? "equity_intraday" : "equity_delivery"
      when "NFO", "BFO" then "futures_options"
      when "CDS" then "currency"
      when "MCX" then "commodity"
      else "other"
      end
    end

    def map_zerodha_asset_class(raw)
      case raw["exchange"]
      when "NSE", "BSE" then raw["product"] == "MIS" ? "swing_trading" : "long_term_equity"
      when "NFO", "BFO" then "swing_trading"
      else "other"
      end
    end
  end
end
