# frozen_string_literal: true

class DebtSnapshot < ApplicationRecord
  belongs_to :debt_account

  monetize :balance_paise, as: :balance, numericality: { greater_than_or_equal_to: 0 }

  validates :recorded_on, presence: true

  scope :chronological, -> { order(:recorded_on) }
  scope :latest_first, -> { order(recorded_on: :desc, id: :desc) }
end
