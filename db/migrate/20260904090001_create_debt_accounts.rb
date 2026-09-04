# DebtAccount is the source of truth for every debt the user owes.
#
# A debt account is either:
#   * "protected"  — serviced normally (home loan, insurance loan, ...)
#   * "settlement" — unsecured debt targeted for settlement negotiation
#
# It can be linked to the existing amortization models (LoanAccount /
# Loan) when the debt is being tracked EMI-wise, or created standalone
# for collection/charged-off accounts that only exist as a claim.
class CreateDebtAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :debt_accounts do |t|
      t.references :user, null: false, foreign_key: true

      # Optional links into the existing loan domain. Exactly one of
      # these may be present; settlement debts usually have neither.
      t.references :loan_account, foreign_key: true
      t.references :loan, foreign_key: true

      t.string  :name, null: false
      t.string  :lender
      t.integer :debt_type, null: false, default: 0        # personal_loan, credit_card, nbfc_loan, ...
      t.integer :classification, null: false, default: 0   # protected / settlement
      t.integer :status, null: false, default: 0           # current, overdue, in_negotiation, ...

      # Amounts are stored as integer paise and exposed as Money objects.
      t.bigint  :original_principal_paise, null: false, default: 0
      t.bigint  :current_balance_paise, null: false, default: 0
      t.bigint  :monthly_obligation_paise, default: 0      # EMI or minimum due; nil for dormant claims
      t.decimal :interest_rate, precision: 6, scale: 3

      t.integer :dpd, null: false, default: 0              # days past due
      t.boolean :formal_notice, null: false, default: false # Lok Adalat / legal notice received
      t.date    :first_defaulted_on
      t.date    :charged_off_on
      t.date    :last_payment_on

      t.text    :notes
      t.integer :priority, null: false, default: 0         # manual nudge inside its stage

      t.timestamps
    end

    add_index :debt_accounts, [:user_id, :classification]
    add_index :debt_accounts, [:user_id, :status]
    add_index :debt_accounts, [:user_id, :debt_type]
  end
end
