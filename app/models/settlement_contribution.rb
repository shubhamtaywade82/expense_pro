# frozen_string_literal: true

# Money set aside towards a future settlement. Contributions build the
# case's settlement fund — they are savings movements, not expenses.
class SettlementContribution < ApplicationRecord
  belongs_to :user
  belongs_to :settlement_case

  validates :contributed_on, presence: true

  monetize :amount_paise, as: :amount, numericality: { greater_than: 0 }

  scope :latest_first, -> { order(contributed_on: :desc, id: :desc) }
  scope :between, ->(from, to) { where(contributed_on: from..to) }
end
