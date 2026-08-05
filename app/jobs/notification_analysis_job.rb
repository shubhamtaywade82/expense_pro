# app/jobs/notification_analysis_job.rb
class NotificationAnalysisJob < ApplicationJob
  queue_as :default

  # Run analysis for all active users
  def perform(*args)
    User.find_each do |user|
      begin
        NotificationIntelligenceService.new(user).analyze_and_create_notifications
      rescue => e
        Rails.logger.error "Notification analysis failed for user #{user.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
end
