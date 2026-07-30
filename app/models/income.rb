class Income < ApplicationRecord
  FREQUENCIES = %w[weekly monthly quarterly yearly one_time].freeze
  enum :income_type, { salary: "salary", freelance: "freelance", bonus: "bonus", fnf: "fnf", other: "other" }

  belongs_to :user
  belongs_to :parent, class_name: "Income", optional: true
  belongs_to :employment, optional: true
  has_many :instances, class_name: "Income", foreign_key: :parent_id, dependent: :destroy
  has_many :tax_deductions, dependent: :destroy

  validates :source, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :income_date, presence: true
  validates :frequency, inclusion: { in: FREQUENCIES }

  scope :for_month, ->(month, year) { where(income_date: Date.new(year, month, 1)..Date.new(year, month, -1)) }
  scope :templates, -> { where(is_recurring: true, parent_id: nil) }
  scope :recent_first, -> { order(income_date: :desc, id: :desc) }

  validate :validate_recurring_rules

  before_save :close_older_ongoing_templates, if: :template?
  before_validation :calculate_net_amount

  def calculate_net_amount
    if gross_amount.present?
      self.amount = gross_amount.to_d - tax_deducted.to_d - pf_deducted.to_d - other_deductions.to_d
    else
      self.gross_amount = amount
    end
  end

  def template?
    is_recurring? && parent_id.nil?
  end

  def instance?
    parent_id.present?
  end

  def ongoing?
    template? && end_date.nil?
  end

  def latest_recurring?
    return false unless template?
    !user.incomes.templates
         .where(source: source)
         .where("income_date > ?", income_date)
         .exists?
  end

  def base_amount
    original_amount || parent&.amount || amount
  end

  def amount_difference
    return 0.0 unless is_custom? || (parent.present? && amount != parent.amount)
    (amount.to_d - base_amount.to_d).to_f
  end

  def gap_info
    return nil unless template?

    next_rule = user.incomes.templates
                    .where(source: source)
                    .where.not(id: id)
                    .where("income_date > ?", income_date)
                    .order(:income_date)
                    .first

    return nil unless next_rule

    if end_date.nil?
      "Overlap: Current rule has no end date, but a newer rule starts on #{next_rule.income_date.strftime('%d %b %Y')}."
    elsif end_date >= next_rule.income_date
      days_overlap = (end_date - next_rule.income_date).to_i + 1
      "Overlap: Overlaps with next rule by #{days_overlap} days."
    elsif end_date < next_rule.income_date - 1.day
      gap_days = (next_rule.income_date - end_date).to_i - 1
      months_gap = (gap_days / 30.0).round(1)
      "Gap: Uncovered gap of #{gap_days} days (~#{months_gap} months) before next rule starts on #{next_rule.income_date.strftime('%d %b %Y')}."
    else
      "Continuous: Seamless transition to next rule starting #{next_rule.income_date.strftime('%d %b %Y')}."
    end
  end

  def as_json(options = {})
    super(options).merge(
      "is_custom" => is_custom || (parent_id.present? && amount != parent&.amount),
      "change_reason" => change_reason,
      "original_amount" => base_amount.to_s,
      "amount_difference" => amount_difference,
      "is_latest_recurring" => latest_recurring?,
      "is_ongoing" => ongoing?,
      "gap_info" => gap_info,
      "income_type" => income_type,
      "gross_amount" => gross_amount,
      "tax_deducted" => tax_deducted,
      "pf_deducted" => pf_deducted,
      "other_deductions" => other_deductions,
      "metadata" => metadata
    )
  end

  private

  def validate_recurring_rules
    return unless template?

    # 1. End date must be on or after start date (income_date)
    if end_date.present? && end_date < income_date
      errors.add(:end_date, "must be on or after the start date (#{income_date.strftime('%d %b %Y')})")
    end

    # 2. Historical/older recurring rules MUST have an end date if a newer rule exists for the same source
    return if user.nil?

    newer_exists = user.incomes.templates
                       .where(source: source)
                       .where.not(id: id)
                       .where("income_date > ?", income_date)
                       .exists?

    if newer_exists && end_date.nil?
      errors.add(:end_date, "must be specified for historical recurring rules. Only the latest recurring rule can be ongoing.")
    end
  end

  def close_older_ongoing_templates
    return if user.nil?

    # Auto-close any older ongoing templates for the same source so date ranges stay valid
    older_ongoing = user.incomes.templates
                        .where(source: source)
                        .where.not(id: id)
                        .where("income_date < ?", income_date)
                        .where(end_date: nil)

    older_ongoing.each do |old_template|
      old_template.update!(end_date: income_date - 1.day)
    end
  end
end
