# frozen_string_literal: true

# Wraps DhanHQ v3.3.0 Models for portfolio, trades, funds, and profile.
# Credentials are resolved per-request by DhanHQ's access_token_provider
# (see config/initializers/dhanhq.rb) — no per-instance client needed.
class DhanDataService
  # User profile and account details
  def profile
    DhanHQ::Models::Profile.fetch&.attributes
  end

  # Current open equity/F&O positions
  def positions
    DhanHQ::Models::Position.all.map(&:attributes)
  end

  # Long-term holdings (CNC stocks held in demat)
  def holdings
    DhanHQ::Models::Holding.all.map(&:attributes)
  end

  # Order book for current trading day
  def orders
    DhanHQ::Models::Order.all.map(&:attributes)
  end

  # Trade book for current trading day (all executed trades)
  def trade_book
    DhanHQ::Models::Trade.today.map(&:attributes)
  end

  # Historical trade log between two dates
  def trade_history(from_date:, to_date:, page: 0)
    DhanHQ::Models::Trade.history(
      from_date: from_date.to_s,
      to_date: to_date.to_s,
      page: page
    ).map(&:attributes)
  end

  # Every page of the historical trade log — used where correctness (P&L
  # aggregation, import) matters more than a single page's worth of rows.
  # Dhan's page size here is 20, not 1000 — an active account can have
  # thousands of fills, so this must report whether it hit the cap rather
  # than silently returning a partial (and therefore wrong) P&L.
  #
  # Capped at 100 pages (2000 trades, ~20s at Dhan's 5 req/sec Data API
  # limit) so a wide range fails fast with `truncated: true` instead of
  # hanging the request for minutes — narrow the date range to get complete,
  # fast results instead.
  MAX_TRADE_HISTORY_PAGES = 100

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

  # Fund limits / available margin
  def fund_limits
    DhanHQ::Models::Funds.fetch&.attributes
  end

  # Ledger / P&L report
  def ledger(from_date:, to_date:)
    DhanHQ::Models::LedgerEntry.all(
      from_date: from_date.to_s,
      to_date: to_date.to_s
    ).map(&:attributes)
  end
end
