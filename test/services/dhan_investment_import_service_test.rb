require "test_helper"

class DhanInvestmentImportServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Import Test User",
      email: "dhan_import_test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  def trade(attrs)
    {
      exchange_segment: "NSE_EQ",
      product_type: "INTRADAY",
      transaction_type: "BUY",
      traded_quantity: 10,
      traded_price: 100,
      sebi_tax: 0,
      stt: 0,
      brokerage_charges: 0,
      service_tax: 0,
      exchange_transaction_charges: 0,
      stamp_duty: 0
    }.merge(attrs).with_indifferent_access
  end

  test "imports importable segments only, skipping equity delivery and commodity" do
    trades = [
      trade(transaction_type: "BUY", traded_quantity: 10, traded_price: 100),
      trade(transaction_type: "SELL", traded_quantity: 10, traded_price: 120),
      trade(exchange_segment: "NSE_EQ", product_type: "CNC", transaction_type: "BUY", traded_quantity: 5, traded_price: 200)
    ]

    imported = DhanInvestmentImportService.new(@user, from_date: "2026-07-01", to_date: "2026-07-31", trades: trades).call

    assert_equal 1, imported.size
    inv = imported.first
    assert_equal "speculative_intraday", inv.asset_class
    assert_equal "realized", inv.status
    assert_equal 200.0, inv.realized_pnl.to_f # 1200 sell - 1000 buy - 0 charges
    assert_equal 1, @user.investments.count
  end

  test "re-running the same period updates the existing investment instead of duplicating" do
    trades = [
      trade(transaction_type: "BUY", traded_quantity: 10, traded_price: 100),
      trade(transaction_type: "SELL", traded_quantity: 10, traded_price: 120)
    ]
    DhanInvestmentImportService.new(@user, from_date: "2026-07-01", to_date: "2026-07-31", trades: trades).call
    assert_equal 1, @user.investments.count

    updated_trades = trades + [ trade(transaction_type: "SELL", traded_quantity: 10, traded_price: 130) ]
    DhanInvestmentImportService.new(@user, from_date: "2026-07-01", to_date: "2026-07-31", trades: updated_trades).call

    assert_equal 1, @user.investments.count
    # buy 1000, sell 1200 + 1300 = 2500, net_pnl = 2500 - 1000 = 1500
    assert_equal 1500.0, @user.investments.first.realized_pnl.to_f
  end

  test "does nothing when no importable trades exist" do
    trades = [ trade(exchange_segment: "NSE_EQ", product_type: "CNC") ]

    imported = DhanInvestmentImportService.new(@user, from_date: "2026-07-01", to_date: "2026-07-31", trades: trades).call

    assert_empty imported
    assert_equal 0, @user.investments.count
  end
end
