class Category < ApplicationRecord
  TYPES = %w[expense income bill loan emi].freeze

  belongs_to :user
  has_many :expenses, dependent: :restrict_with_error
  has_many :monthly_bills, dependent: :restrict_with_error
  has_many :loans, dependent: :restrict_with_error
  has_many :budgets, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :category_type, inclusion: { in: TYPES }
  validates :icon, :color, presence: true

  scope :expense, -> { where(category_type: "expense") }
  scope :income, -> { where(category_type: "income") }

  alias_attribute :type, :category_type

  def as_json(options = {})
    super(options).tap do |hash|
      hash["type"] = hash.delete("categoryType")
    end
  end
end
