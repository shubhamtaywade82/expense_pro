class BrokerImportService
  def initialize(user, adapter, from_date:, to_date:, trades:, manual_asset_class: nil)
    @user = user
    @adapter = adapter
    @from_date = from_date
    @to_date = to_date
    @summary = adapter.compute_pnl_summary(trades)
    @manual_asset_class = manual_asset_class
  end

  def call
    imported = @adapter.importable_segments.filter_map do |segment|
      bucket = @summary[segment]
      next if bucket.nil? || bucket[:trade_count].zero?

      import_segment(segment, bucket, asset_class: segment)
    end

    if @manual_asset_class
      unless @adapter.manual_asset_classes.include?(@manual_asset_class)
        raise ArgumentError, "manual_asset_class must be one of #{@adapter.manual_asset_classes.join(', ')}"
      end

      bucket = @summary["equity_delivery"]
      if bucket && bucket[:trade_count].positive?
        imported << import_segment("equity_delivery", bucket, asset_class: @manual_asset_class)
      end
    end

    imported
  end

  private

  def import_segment(segment, bucket, asset_class:)
    investment = @user.investments.find_or_initialize_by(
      broker_import_key: @adapter.import_key(segment, from_date: @from_date, to_date: @to_date)
    )
    investment.assign_attributes(
      name: @adapter.display_name(segment, from_date: @from_date, to_date: @to_date),
      asset_class: asset_class,
      quantity: 1,
      buy_price: bucket[:buy_value],
      sell_price: bucket[:buy_value] + bucket[:net_pnl],
      purchase_date: @from_date,
      sell_date: @to_date,
      status: "realized",
      notes: "Imported from #{@adapter.broker_name}: #{bucket[:trade_count]} trades, #{@from_date} to #{@to_date}. " \
             "Turnover ₹#{bucket[:buy_value] + bucket[:sell_value]}, charges ₹#{bucket[:charges]}."
    )
    investment.save!
    investment
  end
end
