# frozen_string_literal: true

# AdoptDecimalMoneySchema renames *_cents columns and enforces precision/scale based decimals.
class AdoptDecimalMoneySchema < ActiveRecord::Migration[7.1]
  def up
    rename_column :users, :monthly_income_cents, :monthly_income
    change_column :users, :monthly_income, :decimal, precision: 15, scale: 2, default: 0, null: false

    rename_column :accounts, :current_outstanding_cents, :current_outstanding
    rename_column :accounts, :current_limit_cents, :current_limit
    rename_column :accounts, :current_utilization_bps, :current_utilization
    change_column :accounts, :current_outstanding, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :accounts, :current_limit, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :accounts, :current_utilization, :decimal, precision: 8, scale: 4, default: 0, null: false

    rename_column :loan_details, :principal_cents, :principal
    rename_column :loan_details, :outstanding_cents, :outstanding
    rename_column :loan_details, :emi_cents, :emi
    rename_column :loan_details, :paid_amount_cents, :paid_amount
    rename_column :loan_details, :remaining_amount_cents, :remaining_amount
    rename_column :loan_details, :total_interest_paid_cents, :total_interest_paid
    rename_column :loan_details, :roi_bps, :roi
    change_column :loan_details, :principal, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :loan_details, :outstanding, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :loan_details, :emi, :decimal, precision: 15, scale: 2
    change_column :loan_details, :paid_amount, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :loan_details, :remaining_amount, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :loan_details, :total_interest_paid, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :loan_details, :roi, :decimal, precision: 6, scale: 3

    rename_column :credit_card_details, :outstanding_cents, :outstanding
    rename_column :credit_card_details, :bill_amount_cents, :bill_amount
    rename_column :credit_card_details, :limit_cents, :limit_amount
    rename_column :credit_card_details, :utilization_bps, :utilization
    rename_column :credit_card_details, :paid_amount_cents, :paid_amount
    rename_column :credit_card_details, :remaining_due_cents, :remaining_due
    rename_column :credit_card_details, :apr_bps, :apr
    rename_column :credit_card_details, :min_due_rate_bps, :min_due_rate
    change_column :credit_card_details, :outstanding, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :credit_card_details, :bill_amount, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :credit_card_details, :limit_amount, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :credit_card_details, :utilization, :decimal, precision: 8, scale: 4, default: 0, null: false
    change_column :credit_card_details, :paid_amount, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :credit_card_details, :remaining_due, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :credit_card_details, :apr, :decimal, precision: 6, scale: 3
    change_column :credit_card_details, :min_due_rate, :decimal, precision: 6, scale: 3, default: 5.0, null: false

    rename_column :card_emi_plans, :principal_cents, :principal
    rename_column :card_emi_plans, :emi_cents, :emi
    rename_column :card_emi_plans, :paid_amount_cents, :paid_amount
    rename_column :card_emi_plans, :remaining_amount_cents, :remaining_amount
    rename_column :card_emi_plans, :roi_bps, :roi
    change_column :card_emi_plans, :principal, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :card_emi_plans, :emi, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :card_emi_plans, :paid_amount, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :card_emi_plans, :remaining_amount, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :card_emi_plans, :roi, :decimal, precision: 6, scale: 3

    rename_column :statements, :statement_balance_cents, :statement_balance
    rename_column :statements, :min_due_cents, :min_due
    rename_column :statements, :fees_and_interest_cents, :fees_and_interest
    change_column :statements, :statement_balance, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :statements, :min_due, :decimal, precision: 15, scale: 2, default: 0, null: false
    change_column :statements, :fees_and_interest, :decimal, precision: 15, scale: 2, default: 0, null: false

    rename_column :card_transactions, :amount_cents, :amount
    change_column :card_transactions, :amount, :decimal, precision: 15, scale: 2, null: false

    rename_column :repayment_schedules, :amount_due_cents, :amount_due
    change_column :repayment_schedules, :amount_due, :decimal, precision: 15, scale: 2, default: 0, null: false

    rename_column :payments, :amount_paid_cents, :amount_paid
    change_column :payments, :amount_paid, :decimal, precision: 15, scale: 2, default: 0, null: false

    rename_column :expenses, :amount_cents, :amount
    change_column :expenses, :amount, :decimal, precision: 15, scale: 2, default: 0, null: false
  end

  def down
    change_column :expenses, :amount, :decimal, precision: 20, scale: 4, default: 0, null: false
    rename_column :expenses, :amount, :amount_cents

    change_column :payments, :amount_paid, :decimal, precision: 20, scale: 4, default: 0, null: false
    rename_column :payments, :amount_paid, :amount_paid_cents

    change_column :repayment_schedules, :amount_due, :decimal, precision: 20, scale: 4, default: 0, null: false
    rename_column :repayment_schedules, :amount_due, :amount_due_cents

    change_column :card_transactions, :amount, :decimal, precision: 20, scale: 4, null: false
    rename_column :card_transactions, :amount, :amount_cents

    change_column :statements, :fees_and_interest, :decimal, precision: 20, scale: 4, default: 0, null: false
    change_column :statements, :min_due, :decimal, precision: 20, scale: 4, default: 0, null: false
    change_column :statements, :statement_balance, :decimal, precision: 20, scale: 4, default: 0, null: false
    rename_column :statements, :fees_and_interest, :fees_and_interest_cents
    rename_column :statements, :min_due, :min_due_cents
    rename_column :statements, :statement_balance, :statement_balance_cents

    change_column :card_emi_plans, :roi, :decimal, precision: 20, scale: 4
    change_column :card_emi_plans, :remaining_amount, :decimal, precision: 20, scale: 4, default: 0, null: false
    change_column :card_emi_plans, :paid_amount, :decimal, precision: 20, scale: 4, default: 0, null: false
    change_column :card_emi_plans, :emi, :decimal, precision: 20, scale: 4, default: 0, null: false
    change_column :card_emi_plans, :principal, :decimal, precision: 20, scale: 4, default: 0, null: false
    rename_column :card_emi_plans, :roi, :roi_bps
    rename_column :card_emi_plans, :remaining_amount, :remaining_amount_cents
    rename_column :card_emi_plans, :paid_amount, :paid_amount_cents
    rename_column :card_emi_plans, :emi, :emi_cents
    rename_column :card_emi_plans, :principal, :principal_cents

    change_column :credit_card_details, :min_due_rate, :integer, default: 500, null: false
    change_column :credit_card_details, :apr, :integer
    change_column :credit_card_details, :remaining_due, :decimal, precision: 20, scale: 4, default: 0, null: false
    change_column :credit_card_details, :paid_amount, :decimal, precision: 20, scale: 4, default: 0, null: false
    change_column :credit_card_details, :utilization, :integer, default: 0, null: false
    change_column :credit_card_details, :limit_amount, :decimal, precision: 20, scale: 4, default: 0, null: false
    change_column :credit_card_details, :bill_amount, :decimal, precision: 20, scale: 4, default: 0, null: false
    change_column :credit_card_details, :outstanding, :decimal, precision: 20, scale: 4, default: 0, null: false
    rename_column :credit_card_details, :min_due_rate, :min_due_rate_bps
    rename_column :credit_card_details, :apr, :apr_bps
    rename_column :credit_card_details, :remaining_due, :remaining_due_cents
    rename_column :credit_card_details, :paid_amount, :paid_amount_cents
    rename_column :credit_card_details, :utilization, :utilization_bps
    rename_column :credit_card_details, :limit_amount, :limit_cents
    rename_column :credit_card_details, :bill_amount, :bill_amount_cents
    rename_column :credit_card_details, :outstanding, :outstanding_cents

    change_column :loan_details, :roi, :integer
    change_column :loan_details, :total_interest_paid, :decimal, precision: 20, scale: 4, default: 0, null: false
    change_column :loan_details, :remaining_amount, :decimal, precision: 20, scale: 4, default: 0, null: false
    change_column :loan_details, :paid_amount, :decimal, precision: 20, scale: 4, default: 0, null: false
    change_column :loan_details, :emi, :decimal, precision: 20, scale: 4
    change_column :loan_details, :outstanding, :decimal, precision: 20, scale: 4, default: 0, null: false
    change_column :loan_details, :principal, :decimal, precision: 20, scale: 4, default: 0, null: false
    rename_column :loan_details, :roi, :roi_bps
    rename_column :loan_details, :total_interest_paid, :total_interest_paid_cents
    rename_column :loan_details, :remaining_amount, :remaining_amount_cents
    rename_column :loan_details, :paid_amount, :paid_amount_cents
    rename_column :loan_details, :emi, :emi_cents
    rename_column :loan_details, :outstanding, :outstanding_cents
    rename_column :loan_details, :principal, :principal_cents

    change_column :accounts, :current_utilization, :integer, default: 0, null: false
    change_column :accounts, :current_limit, :decimal, precision: 20, scale: 4, default: 0, null: false
    change_column :accounts, :current_outstanding, :decimal, precision: 20, scale: 4, default: 0, null: false
    rename_column :accounts, :current_utilization, :current_utilization_bps
    rename_column :accounts, :current_limit, :current_limit_cents
    rename_column :accounts, :current_outstanding, :current_outstanding_cents

    change_column :users, :monthly_income, :decimal, precision: 20, scale: 4, default: 0, null: false
    rename_column :users, :monthly_income, :monthly_income_cents
  end
end
