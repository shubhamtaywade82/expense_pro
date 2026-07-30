class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :financial_account
  belongs_to :category
  belongs_to :loan_account
  belongs_to :taggable, polymorphic: true
end
