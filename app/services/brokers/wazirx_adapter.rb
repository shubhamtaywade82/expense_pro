module Brokers
  class WazirXAdapter < BaseAdapter
    BASE_URL = "https://api.wazirx.com"

    def self.broker_type = "wazirx"
    def self.display_name = "WazirX"
    def self.asset_classes = [:crypto]
    def self.auth_type = :api_key_secret
    def self.required_credentials = [:api_key, :api_secret]
    def self.rate_limit = { requests_per_second: 10, burst: 20 }
    def self.documentation_url = "https://docs.wazirx.com/"

    def tax_category = :crypto
    def tds_applicable? = true
    def tds_rate = 0.01

    def authenticate!
      raw = signed_get("/api/v2/funds")
      raise AuthenticationError, "Invalid credentials" unless raw.is_a?(Array)
      { success: true, account_info: { balances: raw.size } }
    end

    def token_valid?
      authenticate![:success]
    rescue
      false
    end

    def holdings
      raw = signed_get("/api/v2/funds")
      raw.select { |f| f["balance"].to_f > 0 }.map do |f|
        NormalizedHolding.new(
          broker: "wazirx",
          symbol: f["currency"]&.upcase,
          name: f["currency"]&.upcase,
          quantity: f["balance"].to_f,
          avg_price: nil,
          current_price: nil,
          asset_class: "crypto_currency",
          raw_data: f
        )
      end
    end

    def positions = []  # WazirX is spot-only

    def trades(from_date:, to_date:)
      # WazirX: GET /api/v2/orders with pagination
      # Note: WazirX API only returns last 500 orders
      # For full history, users must export CSV from WazirX dashboard
      raw = signed_get("/api/v2/orders", params: { limit: 500 })
      (raw || [])
        .select { |o| o["status"] == "executed" }
        .select { |o| in_range?(o["created_at"], from_date, to_date) }
        .map { |o| normalize_trade(o) }
    end

    def trade_history_all(from_date:, to_date:, &progress_block)
      # WazirX limitation: only 500 recent orders via API
      # Return what we can + flag the limitation
      trades = trades(from_date: from_date, to_date: to_date)
      progress_block&.call({
        trades_fetched: trades.size,
        warning: "WazirX API returns only last 500 orders. For complete history, export CSV from WazirX dashboard."
      })
      trades
    end

    def fund_limits
      raw = signed_get("/api/v2/funds")
      { balances: raw.map { |f| { currency: f["currency"], balance: f["balance"].to_f } } }
    end

    def ledger(from_date:, to_date:)
      trades(from_date: from_date, to_date: to_date)
    end

    def pnl_summary(from_date:, to_date:)
      trades = trades(from_date: from_date, to_date: to_date)
      {
        realized_pnl: trades.select(&:sell?).sum(&:amount) - trades.select(&:buy?).sum(&:amount),
        total_volume: trades.sum(&:amount),
        tds_deducted: trades.select(&:sell?).sum { |t| t.amount * 0.01 }
      }
    end

    private

    def signed_get(path, params: {})
      @rate_limiter.throttle!
      timestamp = (Time.now.to_f * 1000).to_i.to_s
      query = params.merge(apiKey: @credential.api_key, recvWindow: 30_000, timestamp: timestamp)
      query_string = query.sort.map { |k, v| "#{k}=#{v}" }.join("&")
      signature = OpenSSL::HMAC.hexdigest("SHA256", @credential.api_secret, query_string)

      response = connection.get("#{path}?#{query_string}&signature=#{signature}")
      handle_response(response)
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL) { |f| f.options.timeout = 30 }
    end

    def handle_response(response)
      case response.status
      when 200 then JSON.parse(response.body)
      when 401, 403 then raise AuthenticationError, "Invalid API credentials"
      when 429 then raise RateLimitError, "Rate limit exceeded"
      else raise APIError.new("WazirX error", status: response.status, body: response.body)
      end
    end

    def normalize_trade(raw)
      NormalizedTrade.new(
        broker: "wazirx",
        exchange_trade_id: raw["id"]&.to_s,
        symbol: raw["market"],
        name: raw["market"],
        segment: "crypto_spot",
        asset_class: "crypto_currency",
        trade_type: raw["side"]&.downcase == "buy" ? :buy : :sell,
        quantity: raw["executed_qty"].to_f,
        price: raw["avg_price"].to_f,
        amount: raw["executed_qty"].to_f * raw["avg_price"].to_f,
        trade_date: Time.at(raw["created_at"].to_i).to_datetime,
        charges: { fee: raw["fee"].to_f },
        raw_data: raw
      )
    end

    def in_range?(timestamp, from, to)
      ts = Time.at(timestamp.to_i).to_date
      ts >= from && ts <= to
    end
  end
end
