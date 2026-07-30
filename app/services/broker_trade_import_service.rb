class BrokerTradeImportService
  def initialize(user, adapter, trades)
    @user = user
    @adapter = adapter
    @trades = trades
  end

  def call
    imported = 0

    @trades.each do |raw|
      attrs = @adapter.trade_attributes_from_raw(raw)
      next if attrs[:exchange_trade_id].blank?

      trade = @user.trades.find_or_initialize_by(
        broker: @adapter.broker_key,
        exchange_trade_id: attrs[:exchange_trade_id]
      )

      trade.assign_attributes(attrs)
      trade.raw_data = raw if trade.new_record? || trade.changed?
      trade.save! if trade.new_record? || trade.changed?
      imported += 1
    end

    imported
  end
end
