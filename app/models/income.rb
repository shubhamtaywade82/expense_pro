class Income < ApplicationRecord
  FREQUENCIES = %w[weekly monthly quarterly yearly one_time].freeze

  belongs_to :user
  belongs_to :parent, class_name: "Income", optional: true
  has_many :instances, class_name: "Income", foreign_key: :parent_id, dependent: :destroy

  validates :source, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :income_date, presence: true
  validates :frequency, inclusion: { in: FREQUENCIES }

  scope :for_month, ->(month, year) { where(income_date: Date.new(year, month, 1)..Date.new(year, month, -1)) }
  scope :templates, -> { where(is_recurring: true, parent_id: nil) }
  scope :recent_first, -> { order(income_date: :desc, id: :desc) }

  def template?
    is_recurring? && parent_id.nil?
  end

  def instance?
    parent_id.present?
  end
end
