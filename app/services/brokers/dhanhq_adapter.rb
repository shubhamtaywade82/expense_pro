module Brokers
  class DhanHQAdapter < BaseAdapter
    DEFAULT_TOKEN_SERVICE_URL = "https://algo-trading-api.onrender.com/auth/dhan/token"

    CHARGE_FIELDS = %i[
      sebi_tax stt brokerage_charges service_tax exchange_transaction_charges stamp_duty
    ].freeze

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

    CHARGE_MAP = {
      sebi_tax: :sebi_tax,
      stt: :stt,
      brokerage_charges: :brokerage,
      service_tax: :gst,
      exchange_transaction_charges: :exchange_charges,
      stamp_duty: :stamp_duty
    }.freeze

    MAX_TRADE_HISTORY_PAGES = 250

    def broker_key
      "dhan"
    end

    def broker_name
      "DhanHQ"
    end

    def profile
      DhanHQ::Models::Profile.fetch&.attributes
    end

    def positions
      DhanHQ::Models::Position.all.map(&:attributes)
    end

    def holdings
      DhanHQ::Models::Holding.all.map(&:attributes)
    end

    def orders
      DhanHQ::Models::Order.all.map(&:attributes)
    end

    def trade_book
      DhanHQ::Models::Trade.today.map(&:attributes)
    end

    def trade_history(from_date:, to_date:, page: 0)
      DhanHQ::Models::Trade.history(
        from_date: from_date.to_s,
        to_date: to_date.to_s,
        page: page
      ).map(&:attributes)
    end

    def trade_history_all(from_date:, to_date:)
      trades = []
      truncated = false

      MAX_TRADE_HISTORY_PAGES.times do |page|
        page_trades = trade_history(from_date: from_date, to_date: to_date, page: page)
        break if page_trades.empty?

        trades.concat(page_trades)
        truncated = true if page == MAX_TRADE_HISTORY_PAGES - 1
      end

      { trades: trades, truncated: truncated }
    end

    def fund_limits
      DhanHQ::Models::Funds.fetch&.attributes
    end

    def ledger(from_date:, to_date:)
      DhanHQ::Models::LedgerEntry.all(
        from_date: from_date.to_s,
        to_date: to_date.to_s
      ).map(&:attributes)
    end

    def segment_key(trade)
      segment = trade[:exchange_segment].to_s
      product = trade[:product_type].to_s

      return "non_speculative_fo" if segment.include?("FNO")
      return "commodity" if segment.include?("MCX")
      return "speculative_intraday" if segment.include?("EQ") && product == "INTRADAY"
      return "equity_delivery" if segment.include?("EQ") && product == "CNC"

      "other"
    end

    def compute_pnl_summary(trades)
      buckets = Hash.new { |h, k| h[k] = { buy_value: 0.0, sell_value: 0.0, charges: 0.0, net_pnl: 0.0, trade_count: 0 } }

      trades.each do |trade|
        seg = segment_key(trade)
        value = trade[:traded_quantity].to_f * trade[:traded_price].to_f
        charges = CHARGE_FIELDS.sum { |f| trade[f].to_f }

        buckets[seg][:trade_count] += 1
        buckets[seg][:charges] += charges
        if trade[:transaction_type] == "BUY"
          buckets[seg][:buy_value] += value
        else
          buckets[seg][:sell_value] += value
        end
      end

      buckets.each_value { |b| b[:net_pnl] = (b[:sell_value] - b[:buy_value] - b[:charges]).round(2) }
      buckets.transform_values { |b| b.transform_values { |v| v.is_a?(Float) ? v.round(2) : v } }
    end

    def importable_segments
      %w[speculative_intraday non_speculative_fo]
    end

    def manual_asset_classes
      %w[swing_trading long_term_equity]
    end

    def client_id
      credential = Current.user && BrokerCredential.find_by(user: Current.user, broker: broker_key)
      credential&.client_id.presence || ENV.fetch("DHAN_CLIENT_ID", ENV.fetch("CLIENT_ID", nil))
    end

    def current_token!
      return Current.dhan_access_token if Current.dhan_access_token.present?

      stored = BrokerAccessToken.active(Current.user, broker: broker_key)
      if stored.present?
        Current.dhan_access_token = stored.access_token
        return stored.access_token
      end

      fetch_and_store!
    end

    def fetch_and_store!
      user = Current.user
      raise "No current user" unless user

      token_info = fetch_from_render_api(user) || fetch_from_env(user)
      raise TokenUnavailableError, "No token available for #{user.email}" unless token_info

      BrokerAccessToken.create!(
        user: user,
        broker: broker_key,
        access_token: token_info[:access_token],
        expires_at: token_info[:expires_at]
      )

      Current.dhan_access_token = token_info[:access_token]
      token_info[:access_token]
    end

    def force_refresh!
      Current.dhan_access_token = nil
      fetch_and_store!
    end

    def trade_attributes_from_raw(raw)
      attrs = { broker: broker_key }

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

    private

    def parse_time(raw, key)
      val = raw[key.to_s] || raw[key]
      val.present? ? Time.parse(val.to_s) : nil
    rescue StandardError
      nil
    end

    def fetch_from_render_api(user)
      credential = BrokerCredential.find_by(user: user, broker: broker_key)
      url = credential&.token_service_url.presence || ENV.fetch("DHAN_TOKEN_SERVICE_URL", DEFAULT_TOKEN_SERVICE_URL)
      bearer = credential&.token_service_secret.presence || ENV.fetch("DHAN_TOKEN_ACCESS_TOKEN", nil)
      return nil if bearer.blank? || url.blank?

      response = HTTParty.get(
        url,
        headers: { "Authorization" => "Bearer #{bearer}", "Content-Type" => "application/json" },
        timeout: 10
      )

      return nil unless response.success?

      body = response.parsed_response
      access_token = body["access_token"]
      expires_at = body["expires_at"] ? Time.parse(body["expires_at"]) : 30.days.from_now

      return nil if access_token.blank?

      { access_token: access_token, expires_at: expires_at }
    rescue StandardError => e
      Rails.logger.warn("[DhanHQAdapter] Render API fetch failed: #{e.message}")
      nil
    end

    def fetch_from_env(user)
      credential = BrokerCredential.find_by(user: user, broker: broker_key)
      token = credential&.fallback_access_token.presence || ENV.fetch("DHAN_ACCESS_TOKEN", ENV.fetch("ACCESS_TOKEN", nil))
      return nil if token.blank?

      Rails.logger.info("[DhanHQAdapter] Using fallback access token for #{user.email}.")
      { access_token: token, expires_at: 30.days.from_now }
    end

    class TokenUnavailableError < StandardError; end
  end
end
