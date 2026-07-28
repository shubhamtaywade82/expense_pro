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
