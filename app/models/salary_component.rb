class SalaryComponent < ApplicationRecord
  belongs_to :employment

  COMPONENT_TYPES = %w[basic hra lta special_allowance bonus pf employer_pf gratuity insurance other].freeze

  validates :component_type, presence: true, inclusion: { in: COMPONENT_TYPES }
  validates :monthly_amount, numericality: { greater_than_or_equal_to: 0 }

  scope :taxable, -> { where(is_taxable: true) }
  scope :exempt_80c, -> { where(is_exempt_under_80c: true) }

  def yearly_amount
    monthly_amount.to_d * 12
  end
end
