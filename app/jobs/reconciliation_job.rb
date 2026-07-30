class ReconciliationJob < ApplicationJob
  queue_as :default
  
  def perform(user_id:, financial_year:)
    user = User.find(user_id)
    ReconciliationService.new(user, financial_year).call
  ensure
    Current.reset if defined?(Current)
  end
end
