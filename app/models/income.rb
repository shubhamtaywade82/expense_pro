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

  def base_amount
    original_amount || parent&.amount || amount
  end

  def amount_difference
    return 0.0 unless is_custom? || (parent.present? && amount != parent.amount)
    (amount.to_d - base_amount.to_d).to_f
  end

  def as_json(options = {})
    super(options).merge(
      "is_custom" => is_custom || (parent_id.present? && amount != parent&.amount),
      "change_reason" => change_reason,
      "original_amount" => base_amount.to_s,
      "amount_difference" => amount_difference
    )
  end
end
