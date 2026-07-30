class Transaction < ApplicationRecord
  belongs_to :user
  belongs_to :financial_account, optional: true
  belongs_to :category, optional: true
  belongs_to :loan_account, optional: true
  belongs_to :taggable, polymorphic: true, optional: true

  enum :status, { pending: 0, completed: 1, failed: 2, cancelled: 3 }
end
