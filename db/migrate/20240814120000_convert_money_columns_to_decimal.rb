# frozen_string_literal: true

# ConvertMoneyColumnsToDecimal switches paise-based bigint columns to high precision decimals.
class ConvertMoneyColumnsToDecimal < ActiveRecord::Migration[7.1]
  def up
    change_column :users, :monthly_income_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "monthly_income_cents::numeric / 100.0"

    change_column :accounts, :current_outstanding_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "current_outstanding_cents::numeric / 100.0"
    change_column :accounts, :current_limit_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "current_limit_cents::numeric / 100.0"

    change_column :loan_details, :principal_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "loan_details.principal_cents::numeric / 100.0"
    change_column :loan_details, :outstanding_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "loan_details.outstanding_cents::numeric / 100.0"
    change_column :loan_details, :emi_cents, :decimal, precision: 20, scale: 4,
                  using: "CASE WHEN loan_details.emi_cents IS NULL THEN NULL ELSE loan_details.emi_cents::numeric / 100.0 END"
    change_column :loan_details, :paid_amount_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "loan_details.paid_amount_cents::numeric / 100.0"
    change_column :loan_details, :remaining_amount_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "loan_details.remaining_amount_cents::numeric / 100.0"
    change_column :loan_details, :total_interest_paid_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "loan_details.total_interest_paid_cents::numeric / 100.0"

    change_column :credit_card_details, :outstanding_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "credit_card_details.outstanding_cents::numeric / 100.0"
    change_column :credit_card_details, :bill_amount_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "credit_card_details.bill_amount_cents::numeric / 100.0"
    change_column :credit_card_details, :limit_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "credit_card_details.limit_cents::numeric / 100.0"
    change_column :credit_card_details, :paid_amount_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "credit_card_details.paid_amount_cents::numeric / 100.0"
    change_column :credit_card_details, :remaining_due_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "credit_card_details.remaining_due_cents::numeric / 100.0"

    change_column :card_emi_plans, :principal_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "card_emi_plans.principal_cents::numeric / 100.0"
    change_column :card_emi_plans, :emi_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "card_emi_plans.emi_cents::numeric / 100.0"
    change_column :card_emi_plans, :paid_amount_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "card_emi_plans.paid_amount_cents::numeric / 100.0"
    change_column :card_emi_plans, :remaining_amount_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "card_emi_plans.remaining_amount_cents::numeric / 100.0"

    change_column :statements, :statement_balance_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "statements.statement_balance_cents::numeric / 100.0"
    change_column :statements, :min_due_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "statements.min_due_cents::numeric / 100.0"
    change_column :statements, :fees_and_interest_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "statements.fees_and_interest_cents::numeric / 100.0"

    change_column :card_transactions, :amount_cents, :decimal, precision: 20, scale: 4, null: false,
                  using: "card_transactions.amount_cents::numeric / 100.0"

    change_column :repayment_schedules, :amount_due_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "repayment_schedules.amount_due_cents::numeric / 100.0"

    change_column :payments, :amount_paid_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "payments.amount_paid_cents::numeric / 100.0"

    change_column :expenses, :amount_cents, :decimal, precision: 20, scale: 4, default: 0, null: false,
                  using: "expenses.amount_cents::numeric / 100.0"
  end

  def down
    change_column :users, :monthly_income_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(monthly_income_cents * 100))::bigint"

    change_column :accounts, :current_outstanding_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(current_outstanding_cents * 100))::bigint"
    change_column :accounts, :current_limit_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(current_limit_cents * 100))::bigint"

    change_column :loan_details, :principal_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(loan_details.principal_cents * 100))::bigint"
    change_column :loan_details, :outstanding_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(loan_details.outstanding_cents * 100))::bigint"
    change_column :loan_details, :emi_cents, :bigint,
                  using: "CASE WHEN loan_details.emi_cents IS NULL THEN NULL ELSE (ROUND(loan_details.emi_cents * 100))::bigint END"
    change_column :loan_details, :paid_amount_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(loan_details.paid_amount_cents * 100))::bigint"
    change_column :loan_details, :remaining_amount_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(loan_details.remaining_amount_cents * 100))::bigint"
    change_column :loan_details, :total_interest_paid_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(loan_details.total_interest_paid_cents * 100))::bigint"

    change_column :credit_card_details, :outstanding_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(credit_card_details.outstanding_cents * 100))::bigint"
    change_column :credit_card_details, :bill_amount_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(credit_card_details.bill_amount_cents * 100))::bigint"
    change_column :credit_card_details, :limit_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(credit_card_details.limit_cents * 100))::bigint"
    change_column :credit_card_details, :paid_amount_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(credit_card_details.paid_amount_cents * 100))::bigint"
    change_column :credit_card_details, :remaining_due_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(credit_card_details.remaining_due_cents * 100))::bigint"

    change_column :card_emi_plans, :principal_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(card_emi_plans.principal_cents * 100))::bigint"
    change_column :card_emi_plans, :emi_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(card_emi_plans.emi_cents * 100))::bigint"
    change_column :card_emi_plans, :paid_amount_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(card_emi_plans.paid_amount_cents * 100))::bigint"
    change_column :card_emi_plans, :remaining_amount_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(card_emi_plans.remaining_amount_cents * 100))::bigint"

    change_column :statements, :statement_balance_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(statements.statement_balance_cents * 100))::bigint"
    change_column :statements, :min_due_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(statements.min_due_cents * 100))::bigint"
    change_column :statements, :fees_and_interest_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(statements.fees_and_interest_cents * 100))::bigint"

    change_column :card_transactions, :amount_cents, :bigint, null: false,
                  using: "(ROUND(card_transactions.amount_cents * 100))::bigint"

    change_column :repayment_schedules, :amount_due_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(repayment_schedules.amount_due_cents * 100))::bigint"

    change_column :payments, :amount_paid_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(payments.amount_paid_cents * 100))::bigint"

    change_column :expenses, :amount_cents, :bigint, default: 0, null: false,
                  using: "(ROUND(expenses.amount_cents * 100))::bigint"
  end
end
