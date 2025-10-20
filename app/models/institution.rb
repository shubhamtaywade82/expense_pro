# frozen_string_literal: true

# Institution represents the lender or card issuer associated with a user's accounts.
class Institution < ApplicationRecord
  enum kind: { bank: 0, nbfc: 1, issuer: 2, other: 3 }

  has_many :accounts, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :kind, presence: true
end
