# frozen_string_literal: true

# Aggregates DhanHQ trade history into the same segment buckets
# TaxCalculatorService/Investment#asset_class already understand
# (speculative_intraday, non_speculative_fo), plus two read-only-only
# buckets (equity_delivery, commodity) that aren't auto-imported because
# accurate STCG/LTCG classification needs FIFO lot-matching this raw trade
# log doesn't give us.
class DhanPnlSummaryService
  IMPORTABLE_SEGMENTS = %w[speculative_intraday non_speculative_fo].freeze
  ALL_SEGMENTS = (IMPORTABLE_SEGMENTS + %w[equity_delivery commodity other]).freeze

  CHARGE_FIELDS = %i[
    sebi_tax stt brokerage_charges service_tax exchange_transaction_charges stamp_duty
  ].freeze

  def initialize(trades)
    @trades = trades
  end

  # @return [Hash] { "speculative_intraday" => { buy_value:, sell_value:, charges:, net_pnl:, trade_count: }, ... }
  def call
    buckets = ALL_SEGMENTS.index_with { blank_bucket }

    @trades.each do |trade|
      bucket = buckets[segment_for(trade)]
      value = trade[:traded_quantity].to_f * trade[:traded_price].to_f
      charges = CHARGE_FIELDS.sum { |f| trade[f].to_f }

      bucket[:trade_count] += 1
      bucket[:charges] += charges
      if trade[:transaction_type] == "BUY"
        bucket[:buy_value] += value
      else
        bucket[:sell_value] += value
      end
    end

    buckets.each_value { |b| b[:net_pnl] = (b[:sell_value] - b[:buy_value] - b[:charges]).round(2) }
    buckets.transform_values { |b| b.transform_values { |v| v.is_a?(Float) ? v.round(2) : v } }
  end

  private

  def blank_bucket
    { buy_value: 0.0, sell_value: 0.0, charges: 0.0, net_pnl: 0.0, trade_count: 0 }
  end

  def segment_for(trade)
    segment = trade[:exchange_segment].to_s
    product = trade[:product_type].to_s

    return "non_speculative_fo" if segment.include?("FNO")
    return "commodity" if segment.include?("MCX")
    return "speculative_intraday" if segment.include?("EQ") && product == "INTRADAY"
    return "equity_delivery" if segment.include?("EQ") && product == "CNC"

    "other"
  end
end
