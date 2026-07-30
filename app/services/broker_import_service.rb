class BrokerImportService
  def initialize(user, broker_type)
    @user = user
    @broker_type = broker_type
    @credential = user.broker_credentials.find_by!(broker_type: broker_type, status: :active)
    @adapter = @credential.adapter
  end

  # ── Import Trades as Investments ──

  def import_investments(from_date:, to_date:, manual_asset_class: nil)
    @adapter.ensure_valid_token! if @credential.respond_to?(:ensure_valid_token!)

    trades = @adapter.trade_history_all(from_date: from_date, to_date: to_date) do |progress|
      Rails.cache.write(cache_key("progress"), progress, expires_in: 10.minutes)
    end

    imported = []
    skipped = 0

    trades.each do |trade|
      asset_class = manual_asset_class || trade.asset_class

      investment = @user.investments.find_or_initialize_by(
        broker_import_key: "#{trade.broker}:#{trade.exchange_trade_id}"
      )

      if investment.new_record?
        investment.assign_attributes(
          name: trade.name,
          asset_class: asset_class,
          broker: trade.broker,
          purchase_date: trade.trade_date.to_date,
          purchase_price: trade.price,
          quantity: trade.quantity,
          invested_amount: trade.amount,
          current_value: trade.amount,
          status: :active,
          metadata: {
            "broker" => trade.broker,
            "segment" => trade.segment,
            "trade_type" => trade.trade_type,
            "exchange_trade_id" => trade.exchange_trade_id,
            "charges" => trade.charges
          }
        )
        investment.save!
        imported << investment
      else
        skipped += 1
      end
    end

    {
      broker: @broker_type,
      total_trades: trades.size,
      imported: imported.size,
      skipped: skipped,
      from_date: from_date,
      to_date: to_date
    }
  end

  # ── Import Trades as Trade Records (for P&L) ──

  def import_trades(from_date:, to_date:)
    @adapter.ensure_valid_token! if @credential.respond_to?(:ensure_valid_token!)

    trades = @adapter.trade_history_all(from_date: from_date, to_date: to_date) do |progress|
      Rails.cache.write(cache_key("progress"), progress, expires_in: 10.minutes)
    end

    imported = []
    skipped = 0

    trades.each do |trade|
      existing = @user.trades.find_by(exchange_trade_id: trade.exchange_trade_id, broker: trade.broker)
      next (skipped += 1) if existing

      @user.trades.create!(
        broker: trade.broker,
        exchange_trade_id: trade.exchange_trade_id,
        symbol: trade.symbol,
        name: trade.name,
        segment: trade.segment,
        trade_type: trade.trade_type,
        quantity: trade.quantity,
        price: trade.price,
        amount: trade.amount,
        trade_date: trade.trade_date,
        charges: trade.charges,
        raw_data: trade.raw_data
      )
      imported << trade
    end

    {
      broker: @broker_type,
      total: trades.size,
      imported: imported.size,
      skipped: skipped
    }
  end

  # ── Sync Holdings Snapshot ──

  def sync_holdings!
    return unless @adapter.supports_holdings?

    holdings = @adapter.holdings
    BrokerSnapshotSyncService.new(@user, broker: @broker_type).sync_holdings!(holdings.map(&:raw_data))
    holdings
  end

  # ── Sync Positions Snapshot ──

  def sync_positions!
    return [] unless @adapter.supports_positions?

    positions = @adapter.positions
    BrokerSnapshotSyncService.new(@user, broker: @broker_type).sync_positions!(positions.map(&:raw_data))
    positions
  end

  # ── P&L Report ──

  def pnl_report(from_date:, to_date:)
    if @adapter.supports_pnl_summary?
      @adapter.pnl_summary(from_date: from_date, to_date: to_date)
    else
      compute_pnl_from_trades(from_date, to_date)
    end
  end

  private

  def compute_pnl_from_trades(from_date, to_date)
    trades = @adapter.trades(from_date: from_date, to_date: to_date)
    sells = trades.select(&:sell?)
    buys = trades.select(&:buy?)

    {
      realized_pnl: sells.sum(&:amount) - buys.sum(&:amount),
      total_buy_volume: buys.sum(&:amount),
      total_sell_volume: sells.sum(&:amount),
      total_charges: trades.sum { |t| t.charges.values.sum },
      tds_deducted: @adapter.tds_applicable? ? sells.sum { |t| t.amount * @adapter.tds_rate } : 0
    }
  end

  def cache_key(suffix)
    "broker:#{@broker_type}:#{@user.id}:#{suffix}"
  end
end
