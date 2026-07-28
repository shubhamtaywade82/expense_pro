# frozen_string_literal: true

# Turns a period's Dhan trades into Investment records the existing
# TaxCalculatorService/ITR pipeline already understands. One aggregate
# Investment per segment per period; re-running the same period updates it
# in place (broker_import_key).
#
# speculative_intraday/non_speculative_fo auto-import — a raw trade log
# classifies them without ambiguity. equity_delivery (CNC) only imports when
# the caller passes manual_asset_class: the trade log alone can't tell STCG
# from LTCG without FIFO lot-matching, so the user picks the bucket manually
# instead of the system guessing wrong.
class DhanInvestmentImportService
  MANUAL_SEGMENT = "equity_delivery"
  MANUAL_ASSET_CLASSES = %w[swing_trading long_term_equity].freeze

  def initialize(user, from_date:, to_date:, trades:, manual_asset_class: nil)
    @user = user
    @from_date = from_date
    @to_date = to_date
    @summary = DhanPnlSummaryService.new(trades).call
    @manual_asset_class = manual_asset_class
  end

  def call
    imported = DhanPnlSummaryService::IMPORTABLE_SEGMENTS.filter_map do |segment|
      bucket = @summary[segment]
      next if bucket[:trade_count].zero?

      import_segment(segment, bucket, asset_class: segment)
    end

    if @manual_asset_class
      unless MANUAL_ASSET_CLASSES.include?(@manual_asset_class)
        raise ArgumentError, "manual_asset_class must be one of #{MANUAL_ASSET_CLASSES.join(', ')}"
      end

      bucket = @summary[MANUAL_SEGMENT]
      imported << import_segment(MANUAL_SEGMENT, bucket, asset_class: @manual_asset_class) if bucket[:trade_count].positive?
    end

    imported
  end

  private

  def import_segment(segment, bucket, asset_class:)
    investment = @user.investments.find_or_initialize_by(broker_import_key: import_key(segment))
    investment.assign_attributes(
      name: display_name(segment),
      asset_class: asset_class,
      quantity: 1,
      buy_price: bucket[:buy_value],
      sell_price: bucket[:buy_value] + bucket[:net_pnl],
      purchase_date: @from_date,
      sell_date: @to_date,
      status: "realized",
      notes: "Imported from Dhan: #{bucket[:trade_count]} trades, #{@from_date} to #{@to_date}. " \
             "Turnover ₹#{bucket[:buy_value] + bucket[:sell_value]}, charges ₹#{bucket[:charges]}."
    )
    investment.save!
    investment
  end

  def import_key(segment)
    "dhan:#{segment}:#{@from_date}:#{@to_date}"
  end

  def display_name(segment)
    label = case segment
    when "speculative_intraday" then "Dhan Intraday Trading"
    when "non_speculative_fo" then "Dhan F&O Trading"
    when MANUAL_SEGMENT then "Dhan Equity Delivery"
    end
    "#{label} (#{@from_date} to #{@to_date})"
  end
end
