# frozen_string_literal: true

require "bigdecimal"
require "bigdecimal/util"

# User represents the portfolio owner and exposes helpers for dashboard summaries.
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :accounts, dependent: :destroy
  has_many :expenses, dependent: :destroy

  validates :full_name, presence: true
  validates :time_zone, presence: true
  validates :monthly_income, numericality: { greater_than_or_equal_to: 0 }

  before_validation :set_default_time_zone

  SUMMARY_PERIODS = {
    day: -> { [Date.current, Date.current] },
    week: -> { [Date.current.beginning_of_week, Date.current.end_of_week] },
    month: -> { [Date.current.beginning_of_month, Date.current.end_of_month] },
    all: -> { [Date.new(2000, 1, 1), Date::Infinity.new] }
  }.freeze

  # @param period [:day, :week, :month, :all] reporting period key.
  # @return [BigDecimal] total amount due in rupees for the period.
  def total_due_in_period(period)
    from, to = period_bounds(period)
    accounts
      .joins(:repayment_schedules)
      .merge(RepaymentSchedule.due_between(from, to))
      .sum(:amount_due)
  end

  # @param period [:day, :week, :month, :all] reporting period key.
  # @return [BigDecimal] total amount paid in rupees for the period.
  def total_paid_in_period(period)
    from, to = period_bounds(period)
    accounts
      .joins(repayment_schedules: :payments)
      .where(payments: { paid_on: from..to })
      .sum(:amount_paid)
  end

  # @param period [:day, :week, :month, :all] reporting period key.
  # @return [BigDecimal] total discretionary expenses in rupees for the period.
  def total_expenses_in_period(period)
    from, to = period_bounds(period)
    expenses.between(from, to).sum(:amount)
  end

  # @return [Float] portfolio-wide credit card utilisation (0-1 scale).
  def card_utilization_ratio
    cards = accounts.cards
    limit_value = decimal_or_zero(cards.sum(:current_limit))
    return 0.0 if limit_value.zero?

    outstanding_value = decimal_or_zero(cards.sum(:current_outstanding))
    outstanding_value.fdiv(limit_value).to_f
  end

  private

  def set_default_time_zone
    self.time_zone ||= "Asia/Kolkata"
  end

  def period_bounds(period)
    fetcher = SUMMARY_PERIODS.fetch(period.to_sym) { SUMMARY_PERIODS[:all] }
    fetcher.call
  end

  def decimal_or_zero(value)
    value.nil? ? 0.to_d : value.to_d
  end
end
