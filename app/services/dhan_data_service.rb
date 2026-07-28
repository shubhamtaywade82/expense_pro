# frozen_string_literal: true

# Wraps DhanHQ v3.3.0 API calls for portfolio, trades, funds, and profile.
class DhanDataService
  def initialize
    @client = DhanTokenService.build_client
  end

  # User profile and account details
  def profile
    resp = @client.user_detail
    normalize(resp)
  end

  # Current open equity/F&O positions
  def positions
    resp = @client.positions
    normalize(resp)
  end

  # Long-term holdings (CNC stocks held in demat)
  def holdings
    resp = @client.holdings
    normalize(resp)
  end

  # Order book for current trading day
  def orders
    resp = @client.order_list
    normalize(resp)
  end

  # Trade book for current trading day (all executed trades)
  def trade_book
    resp = @client.trade_book
    normalize(resp)
  end

  # Historical trade log between two dates
  def trade_history(from_date:, to_date:, page: 0)
    resp = @client.trade_history(
      from_date: from_date.to_s,
      to_date: to_date.to_s,
      page: page
    )
    normalize(resp)
  end

  # Fund limits / available margin
  def fund_limits
    resp = @client.fund_limits
    normalize(resp)
  end

  # Ledger / P&L report
  def ledger(from_date:, to_date:)
    resp = @client.ledger_report(
      from_date: from_date.to_s,
      to_date: to_date.to_s
    )
    normalize(resp)
  end

  private

  def normalize(resp)
    return resp if resp.is_a?(Array) || resp.is_a?(Hash)
    resp
  end
end
