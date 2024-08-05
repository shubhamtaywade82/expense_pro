class Income < ApplicationRecord
  belongs_to :user

  validates :source, presence: true
  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :frequency, presence: true
end
