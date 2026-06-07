class Income < ApplicationRecord
  FREQUENCIES = %w[weekly monthly quarterly yearly one_time].freeze

  belongs_to :user

  validates :source, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :income_date, presence: true
  validates :frequency, inclusion: { in: FREQUENCIES }

  scope :for_month, ->(month, year) { where(income_date: Date.new(year, month, 1)..Date.new(year, month, -1)) }
  scope :recent_first, -> { order(income_date: :desc, id: :desc) }
end
