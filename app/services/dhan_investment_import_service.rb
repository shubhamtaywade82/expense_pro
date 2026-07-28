# frozen_string_literal: true

# Turns a period's Dhan trades into Investment records the existing
# TaxCalculatorService/ITR pipeline already understands, for the two
# segments a raw trade log can classify without FIFO lot-matching
# (see DhanPnlSummaryService). One aggregate Investment per segment per
# period; re-running the same period updates it in place (broker_import_key).
class DhanInvestmentImportService
  def initialize(user, from_date:, to_date:, trades:)
    @user = user
    @from_date = from_date
    @to_date = to_date
    @summary = DhanPnlSummaryService.new(trades).call
  end

  def call
    DhanPnlSummaryService::IMPORTABLE_SEGMENTS.filter_map do |segment|
      bucket = @summary[segment]
      next if bucket[:trade_count].zero?

      import_segment(segment, bucket)
    end
  end

  private

  def import_segment(segment, bucket)
    investment = @user.investments.find_or_initialize_by(broker_import_key: import_key(segment))
    investment.assign_attributes(
      name: display_name(segment),
      asset_class: segment,
      quantity: 1,
      buy_price: bucket[:buy_value],
      sell_price: bucket[:buy_value] + bucket[:net_pnl],
      purchase_date: @from_date,
      sell_date: @to_date,
      status: "realized",
      notes: "Auto-imported from Dhan: #{bucket[:trade_count]} trades, #{@from_date} to #{@to_date}. " \
             "Turnover ₹#{bucket[:buy_value] + bucket[:sell_value]}, charges ₹#{bucket[:charges]}."
    )
    investment.save!
    investment
  end

  def import_key(segment)
    "dhan:#{segment}:#{@from_date}:#{@to_date}"
  end

  def display_name(segment)
    label = segment == "speculative_intraday" ? "Dhan Intraday Trading" : "Dhan F&O Trading"
    "#{label} (#{@from_date} to #{@to_date})"
  end
end
