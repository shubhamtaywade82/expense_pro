class BrokerImportJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: ->(executions) { executions**2 * 10.seconds }, attempts: 3

  def perform(user_id:, broker:, from_date:, to_date:, manual_asset_class: nil)
    lock_key = "broker_import_lock:#{broker}:#{user_id}:#{from_date}:#{to_date}"
    return if Rails.cache.exist?(lock_key)
    Rails.cache.write(lock_key, true, expires_in: 10.minutes)

    user = User.find(user_id)
    Current.user = user

    adapter = Brokers::Registry.for(broker)
    result = adapter.trade_history_all(from_date: from_date, to_date: to_date)
    return if result[:truncated]

    BrokerImportService.new(
      user, adapter, from_date: from_date, to_date: to_date,
      trades: result[:trades], manual_asset_class: manual_asset_class
    ).call
  rescue => e
    Rails.cache.write("broker_import:#{broker}:#{user_id}:error", e.message, expires_in: 1.hour)
    raise
  ensure
    Rails.cache.delete(lock_key)
  end
end
