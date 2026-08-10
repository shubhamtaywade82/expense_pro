class AddMultistageFieldsToLoanAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :loan_accounts, :rate_revisions, :jsonb, default: []
    add_column :loan_accounts, :disbursements, :jsonb, default: []
    add_column :loan_accounts, :metadata, :jsonb, default: {}
  end
end
