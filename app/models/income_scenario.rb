# frozen_string_literal: true

# Salary scenarios ("what happens after appraisal?") that feed the
# available-capital calculation and the clearance forecast. One active
# scenario per user drives the default projections.
class IncomeScenario < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :effective_on, presence: true

  enum :scenario_type, {
    current: 0, conservative: 1, base: 2, appraisal: 3, aggressive: 4, custom: 5
  }

  monetize :monthly_income_paise, as: :monthly_income, numericality: { greater_than_or_equal_to: 0 }
  monetize :monthly_commitments_paise, as: :monthly_commitments, numericality: { greater_than_or_equal_to: 0 }
  monetize :settlement_allocation_paise, as: :settlement_allocation, numericality: { greater_than_or_equal_to: 0 }
  monetize :buffer_allocation_paise, as: :buffer_allocation, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(is_active: true) }
  scope :effective, -> { where(effective_on: ..Date.current).or(where(effective_on: nil)) }

  def activate!
    user.income_scenarios.where.not(id: id).update_all(is_active: false) # rubocop:disable Rails/SkipsModelValidations
    update!(is_active: true)
  end

  def monthly_surplus
    monthly_income - monthly_commitments - buffer_allocation
  end

  def monthly_surplus_paise
    [monthly_income_paise - monthly_commitments_paise - buffer_allocation_paise, 0].max
  end
end
