# frozen_string_literal: true

# Wraps DhanHQ v3.3.0 Models for portfolio, trades, funds, and profile.
# Credentials are resolved per-request by DhanHQ's access_token_provider
# (see config/initializers/dhanhq.rb) — no per-instance client needed.
class DhanDataService
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

  # Every page of the historical trade log — used where correctness (P&L
  # aggregation, import) matters more than a single page's worth of rows.
  # Dhan's page size here is 20, not 1000 — an active account can have
  # thousands of fills, so this must report whether it hit the cap rather
  # than silently returning a partial (and therefore wrong) P&L.
  #
  # Capped at 250 pages (5000 trades, ~50s at Dhan's 5 req/sec Data API
  # limit) so a wide range fails fast with `truncated: true` instead of
  # hanging the request for minutes. A full FY for an active F&O trader can
  # still exceed this — import period-by-period (This Month / This Quarter)
  # instead of This FY; each import is its own correctly-dated Investment
  # row and TaxCalculatorService sums all of them for the FY regardless.
  MAX_TRADE_HISTORY_PAGES = 250

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
