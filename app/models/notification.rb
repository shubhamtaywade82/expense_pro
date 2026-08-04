# app/models/notification.rb
class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :subject, presence: true
  validates :message, presence: true
  validates :category, inclusion: { in: %w[tax cash_flow investment info document] }

  # Scopes
  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :archived, -> { where(archived: true) }
  scope :active, -> { where(archived: false) }
  scope :recent, -> { order(created_at: :desc) }

  # Category scopes
  scope :tax_alerts, -> { where(category: 'tax') }
  scope :cash_flow_alerts, -> { where(category: 'cash_flow') }
  scope :investment_alerts, -> { where(category: 'investment') }
  scope :document_alerts, -> { where(category: 'document') }

  # JSONB payload helpers
  store_accessor :payload, :action_url, :action_label, :priority, :metadata

  def mark_read!
    update!(read: true, read_at: Time.current)
  end

  def mark_viewed!
    update!(viewed_at: Time.current) unless viewed_at
  end

  def archive!
    update!(archived: true)
  end

  # Check if notification has actionable button
  def actionable?
    action_url.present? && action_label.present?
  end

  # Priority helper (1=highest, 5=lowest)
  def priority_level
    (priority || 3).to_i
  end

  def urgent?
    priority_level <= 2
  end
end
