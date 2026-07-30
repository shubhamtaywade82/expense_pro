class TaxDeduction < ApplicationRecord
  belongs_to :income

  DEDUCTION_TYPES = %w[tds advance_tax self_assessment_tax].freeze

  validates :deduction_type, presence: true, inclusion: { in: DEDUCTION_TYPES }
  validates :tds_amount, numericality: { greater_than: 0 }

  scope :tds, -> { where(deduction_type: "tds") }
  scope :advance_tax, -> { where(deduction_type: "advance_tax") }
  scope :self_assessment, -> { where(deduction_type: "self_assessment_tax") }
  scope :for_fy, ->(year) {
    fy_start = Date.new(year, 4, 1)
    fy_end = Date.new(year + 1, 3, 31)
    joins(:income).where(income: { income_date: fy_start..fy_end })
  }

  def self.total_for_fy(year)
    for_fy(year).sum(:tds_amount)
  end
end
