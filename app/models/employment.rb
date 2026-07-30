class Employment < ApplicationRecord
  belongs_to :user
  has_many :salary_components, dependent: :destroy
  has_many :incomes, dependent: :nullify

  validates :employer_name, presence: true
  validates :start_date, presence: true
  validates :monthly_ctc, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :current, -> { where(is_current: true) }
  scope :by_recency, -> { order(start_date: :desc) }
end
