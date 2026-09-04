# frozen_string_literal: true

# The strategy layer: "how am I eliminating my debt?" A user keeps one
# default strategy that feeds the settlement queue, the available-capital
# calculation and the clearance forecast.
class DebtStrategy < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :status, inclusion: { in: %w[active paused completed] }

  enum :strategy_type, { normal_repayment: 0, settlement: 1, hybrid: 2 }
  enum :priority_method, {
    smallest_balance: 0, highest_interest: 1, highest_cashflow_impact: 2,
    settlement_opportunity: 3, custom: 4
  }

  monetize :monthly_allocation_paise, as: :monthly_allocation,
           numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(status: "active") }
  scope :default_first, -> { order(is_default: :desc, updated_at: :desc) }

  def set_default!
    user.debt_strategies.where.not(id: id).update_all(is_default: false) # rubocop:disable Rails/SkipsModelValidations
    update!(is_default: true)
  end
end
