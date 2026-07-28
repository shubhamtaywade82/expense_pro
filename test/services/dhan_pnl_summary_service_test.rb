require "test_helper"

class DhanPnlSummaryServiceTest < ActiveSupport::TestCase
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

  test "buckets intraday equity trades and computes net P&L after charges" do
    trades = [
      trade(transaction_type: "BUY", traded_quantity: 10, traded_price: 100, brokerage_charges: 5),
      trade(transaction_type: "SELL", traded_quantity: 10, traded_price: 110, brokerage_charges: 5)
    ]

    summary = DhanPnlSummaryService.new(trades).call

    bucket = summary["speculative_intraday"]
    assert_equal 2, bucket[:trade_count]
    assert_equal 1000.0, bucket[:buy_value]
    assert_equal 1100.0, bucket[:sell_value]
    assert_equal 10.0, bucket[:charges]
    assert_equal 90.0, bucket[:net_pnl] # 1100 - 1000 - 10
    assert_equal 0, summary["non_speculative_fo"][:trade_count]
  end

  test "classifies F&O, equity delivery, and commodity into separate buckets" do
    trades = [
      trade(exchange_segment: "NSE_FNO", product_type: "INTRADAY", transaction_type: "BUY", traded_quantity: 1, traded_price: 500),
      trade(exchange_segment: "NSE_EQ", product_type: "CNC", transaction_type: "BUY", traded_quantity: 5, traded_price: 200),
      trade(exchange_segment: "MCX_COMM", product_type: "INTRADAY", transaction_type: "SELL", traded_quantity: 1, traded_price: 1000)
    ]

    summary = DhanPnlSummaryService.new(trades).call

    assert_equal 1, summary["non_speculative_fo"][:trade_count]
    assert_equal 1, summary["equity_delivery"][:trade_count]
    assert_equal 1, summary["commodity"][:trade_count]
    assert_equal 0, summary["speculative_intraday"][:trade_count]
  end

  test "empty trade list returns zeroed buckets for every segment" do
    summary = DhanPnlSummaryService.new([]).call

    DhanPnlSummaryService::ALL_SEGMENTS.each do |segment|
      assert_equal 0, summary[segment][:trade_count]
      assert_equal 0.0, summary[segment][:net_pnl]
    end
  end
end
