# frozen_string_literal: true

class Investment < ApplicationRecord
  has_paper_trail

  ASSET_CLASSES = %w[
    speculative_intraday
    non_speculative_fo
    swing_trading
    long_term_equity
    mutual_funds
    fixed_income
    crypto
    elss_80c
    gold
  ].freeze

  STATUSES = %w[active realized].freeze

  belongs_to :user

  validates :name, presence: true
  validates :asset_class, inclusion: { in: ASSET_CLASSES }
  validates :status, inclusion: { in: STATUSES }
  validates :quantity, numericality: { greater_than: 0 }
  validates :buy_price, numericality: { greater_than_or_equal_to: 0 }
  validates :purchase_date, presence: true

  before_save :calculate_pnl_and_totals

  scope :active, -> { where(status: "active") }
  scope :realized, -> { where(status: "realized") }
  scope :recent_first, -> { order(purchase_date: :desc, id: :desc) }
  scope :for_year, ->(year) { where(purchase_date: Date.new(year, 1, 1)..Date.new(year, 12, 31)) }

  def current_value
    if status == "realized" && sell_price.present?
      (quantity.to_d * sell_price.to_d).round(2)
    elsif current_price.present?
      (quantity.to_d * current_price.to_d).round(2)
    else
      invested_amount.to_d
    end
  end

  def total_pnl
    if status == "realized"
      realized_pnl.to_d
    else
      unrealized_pnl.to_d
    end
  end

  def pnl_percentage
    return 0.0 if invested_amount.to_d.zero?
    ((total_pnl / invested_amount.to_d) * 100).round(2)
  end

  def stcg?
    return false unless %w[swing_trading long_term_equity mutual_funds].include?(asset_class)
    return false if purchase_date.blank?

    end_d = sell_date || Date.current
    (end_d - purchase_date).to_i < 365
  end

  def ltcg?
    return false unless %w[swing_trading long_term_equity mutual_funds].include?(asset_class)
    return false if purchase_date.blank?

    end_d = sell_date || Date.current
    (end_d - purchase_date).to_i >= 365
  end

  def as_json(options = {})
    super(options).merge(
      "current_value" => current_value.to_s,
      "total_pnl" => total_pnl.to_s,
      "pnl_percentage" => pnl_percentage,
      "is_stcg" => stcg?,
      "is_ltcg" => ltcg?
    )
  end

  private

  def calculate_pnl_and_totals
    qty = quantity.to_d
    buy = buy_price.to_d
    self.invested_amount = (qty * buy).round(2)

    if status == "realized" && sell_price.present?
      self.realized_pnl = ((sell_price.to_d - buy) * qty).round(2)
      self.unrealized_pnl = 0.0
    elsif current_price.present?
      self.unrealized_pnl = ((current_price.to_d - buy) * qty).round(2)
      self.realized_pnl = 0.0
    end
  end
end
