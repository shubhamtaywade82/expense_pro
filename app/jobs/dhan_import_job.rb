class DhanImportJob < ApplicationJob
  queue_as :default

  def perform(user_id:, from_date:, to_date:, manual_asset_class: nil)
    user = User.find(user_id)
    Current.user = user

    result = DhanDataService.new.trade_history_all(from_date: from_date, to_date: to_date)
    return if result[:truncated]

    DhanInvestmentImportService.new(
      user, from_date: from_date, to_date: to_date, trades: result[:trades], manual_asset_class: manual_asset_class
    ).call
  end
end
