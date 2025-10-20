# frozen_string_literal: true

# Account models either a loan or credit card and centralizes balances and schedules.
class Account < ApplicationRecord
  enum account_kind: { loan: 0, credit_card: 1 }
  enum status: { active: 0, closed: 1, delinquent: 2 }

  belongs_to :user
  belongs_to :institution, optional: true

  has_one :loan_detail, dependent: :destroy
  has_one :credit_card_detail, dependent: :destroy

  has_many :card_emi_plans, dependent: :destroy
  has_many :repayment_schedules, dependent: :destroy
  has_many :payments, dependent: :restrict_with_error
  has_many :statements, dependent: :destroy
  has_many :card_transactions, dependent: :destroy

  scope :loans, -> { where(account_kind: :loan) }
  scope :cards, -> { where(account_kind: :credit_card) }

  validates :account_kind, presence: true
  validates :status, presence: true
end
