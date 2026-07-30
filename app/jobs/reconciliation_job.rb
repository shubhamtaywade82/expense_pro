class ReconciliationJob < ApplicationJob
  queue_as :default
  
  def perform(user_id:, financial_year:)
    ReconciliationService.new(user_id: user_id, financial_year: financial_year).reconcile!
  ensure
    Current.reset
  end
end
