class DhanSyncJob < ApplicationJob
  queue_as :default

  def perform(user_id:, from_date:, to_date:)
    cache_key = "dhan_sync:#{user_id}"

    user = User.find(user_id)
    Current.user = user

    svc = DhanDataService.new
    snapshot_service = BrokerSnapshotSyncService.new(user, broker: DhanTokenService::BROKER)

    snapshot_service.sync_holdings!(svc.holdings)
    snapshot_service.sync_positions!(svc.positions)

    result = svc.trade_history_all(from_date:, to_date:)

    if result[:truncated]
      Rails.cache.write("#{cache_key}:status", "truncated", expires_in: 5.minutes)
      Rails.cache.write("#{cache_key}:trades", 0, expires_in: 5.minutes)
      return
    end

    imported = DhanInvestmentImportService.new(
      user, from_date:, to_date:, trades: result[:trades]
    ).call

    Rails.cache.write("#{cache_key}:status", "completed", expires_in: 5.minutes)
    Rails.cache.write("#{cache_key}:trades", imported.size, expires_in: 5.minutes)
  end
end
