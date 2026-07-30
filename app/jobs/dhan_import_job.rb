class DhanImportJob < ApplicationJob
  queue_as :default
  retry_on DhanHQ::RateLimitError, wait: 30.seconds, attempts: 5

  def perform(user_id:, from_date:, to_date:, manual_asset_class: nil)
    lock_key = "dhan_import_lock:#{user_id}:#{from_date}:#{to_date}"
    return if Rails.cache.exist?(lock_key)
    Rails.cache.write(lock_key, true, expires_in: 10.minutes)

    user = User.find(user_id)
    Current.user = user

    result = DhanDataService.new.trade_history_all(from_date: from_date, to_date: to_date)
    return if result[:truncated]

    DhanInvestmentImportService.new(
      user, from_date: from_date, to_date: to_date, trades: result[:trades], manual_asset_class: manual_asset_class
    ).call
  rescue => e
    Rails.cache.write("dhan_import:#{user_id}:error", e.message, expires_in: 1.hour)
    raise
  ensure
    Rails.cache.delete(lock_key)
    Current.reset
  end
end
