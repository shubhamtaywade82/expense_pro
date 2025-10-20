# frozen_string_literal: true

class RestructureFinanceSchema < ActiveRecord::Migration[7.1]
  def change
    drop_table :transactions, if_exists: true do |t|
      t.references :credit_card, null: false, foreign_key: true
      t.decimal :amount
      t.string :category
      t.date :date
      t.text :notes
      t.timestamps null: false
    end

    drop_table :credit_cards, if_exists: true do |t|
      t.string :name
      t.string :card_type
      t.date :expiry_date
      t.date :statement_date
      t.date :payment_due_date
      t.boolean :reminder
      t.string :last_four_digits
      t.text :description
      t.text :additional_notes
      t.boolean :has_annual_fee
      t.references :user, null: false, foreign_key: true
      t.timestamps null: false
    end

    drop_table :incomes, if_exists: true do |t|
      t.string :source
      t.text :description
      t.decimal :amount
      t.string :frequency
      t.references :user, null: false, foreign_key: true
      t.timestamps null: false
    end

    drop_table :expenses, if_exists: true do |t|
      t.string :category
      t.text :description
      t.decimal :amount
      t.string :payment_method
      t.string :expense_type
      t.references :user, null: false, foreign_key: true
      t.string :payment_type
      t.references :credit_card, null: false, foreign_key: true
      t.timestamps null: false
    end

    drop_table :users, if_exists: true do |t|
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.string :first_name
      t.string :last_name
      t.string :username
      t.string :mobile
      t.string :country
      t.string :currency
      t.timestamps null: false
    end

    create_table :users, id: :uuid do |t|
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""
      t.string :reset_password_token
      t.datetime :reset_password_sent_at
      t.datetime :remember_created_at
      t.string :full_name, null: false
      t.string :time_zone, null: false, default: "Asia/Kolkata"
      t.bigint :monthly_income_cents, null: false, default: 0
      t.timestamps null: false
    end

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_check_constraint :users, "monthly_income_cents >= 0", name: "users_monthly_income_non_negative"

    create_table :institutions, id: :uuid do |t|
      t.string :name, null: false
      t.integer :kind, null: false, default: 0
      t.timestamps null: false
    end

    add_index :institutions, :name, unique: true

    create_table :accounts, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :institution, foreign_key: true, type: :uuid
      t.integer :account_kind, null: false, default: 0
      t.string :external_ref
      t.date :opened_on
      t.date :closed_on
      t.integer :status, null: false, default: 0
      t.bigint :current_outstanding_cents, null: false, default: 0
      t.bigint :current_limit_cents, null: false, default: 0
      t.integer :current_utilization_bps, null: false, default: 0
      t.text :notes
      t.timestamps null: false
    end

    add_index :accounts, :account_kind
    add_index :accounts, :status
    add_index :accounts, :user_id
    add_index :accounts, :institution_id
    add_check_constraint :accounts, "current_outstanding_cents >= 0", name: "accounts_outstanding_non_negative"
    add_check_constraint :accounts, "current_limit_cents >= 0", name: "accounts_limit_non_negative"
    add_check_constraint :accounts, "current_utilization_bps >= 0", name: "accounts_utilization_non_negative"

    create_table :loan_details, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :loan_type
      t.bigint :principal_cents, null: false, default: 0
      t.bigint :outstanding_cents, null: false, default: 0
      t.bigint :emi_cents
      t.integer :roi_bps
      t.date :start_on
      t.integer :due_day_of_month
      t.bigint :paid_amount_cents, null: false, default: 0
      t.bigint :remaining_amount_cents, null: false, default: 0
      t.date :full_due_on
      t.string :status
      t.integer :tenure_months
      t.integer :months_remaining
      t.bigint :total_interest_paid_cents, null: false, default: 0
      t.text :remarks
      t.timestamps null: false
    end

    add_index :loan_details, :account_id, unique: true
    add_check_constraint :loan_details, "principal_cents >= 0", name: "loan_details_principal_non_negative"
    add_check_constraint :loan_details, "outstanding_cents >= 0", name: "loan_details_outstanding_non_negative"
    add_check_constraint :loan_details, "paid_amount_cents >= 0", name: "loan_details_paid_non_negative"
    add_check_constraint :loan_details, "remaining_amount_cents >= 0", name: "loan_details_remaining_non_negative"
    add_check_constraint :loan_details, "total_interest_paid_cents >= 0", name: "loan_details_interest_non_negative"
    add_check_constraint :loan_details, "due_day_of_month BETWEEN 1 AND 31", name: "loan_details_due_day_range"

    create_table :credit_card_details, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :card_name
      t.integer :statement_day_of_month
      t.integer :due_day_of_month
      t.bigint :outstanding_cents, null: false, default: 0
      t.bigint :bill_amount_cents, null: false, default: 0
      t.bigint :limit_cents, null: false, default: 0
      t.integer :utilization_bps, null: false, default: 0
      t.bigint :paid_amount_cents, null: false, default: 0
      t.bigint :remaining_due_cents, null: false, default: 0
      t.date :full_due_on
      t.string :status
      t.integer :apr_bps
      t.integer :min_due_rate_bps, null: false, default: 500
      t.timestamps null: false
    end

    add_index :credit_card_details, :account_id, unique: true
    add_check_constraint :credit_card_details, "outstanding_cents >= 0", name: "credit_card_details_outstanding_non_negative"
    add_check_constraint :credit_card_details, "bill_amount_cents >= 0", name: "credit_card_details_bill_non_negative"
    add_check_constraint :credit_card_details, "limit_cents >= 0", name: "credit_card_details_limit_non_negative"
    add_check_constraint :credit_card_details, "utilization_bps >= 0", name: "credit_card_details_utilization_non_negative"
    add_check_constraint :credit_card_details, "paid_amount_cents >= 0", name: "credit_card_details_paid_non_negative"
    add_check_constraint :credit_card_details, "remaining_due_cents >= 0", name: "credit_card_details_remaining_non_negative"
    add_check_constraint :credit_card_details, "statement_day_of_month BETWEEN 1 AND 31", name: "credit_card_details_statement_day_range"
    add_check_constraint :credit_card_details, "due_day_of_month BETWEEN 1 AND 31", name: "credit_card_details_due_day_range"

    create_table :card_emi_plans, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.string :plan_name
      t.bigint :principal_cents, null: false, default: 0
      t.bigint :emi_cents, null: false, default: 0
      t.integer :roi_bps
      t.date :start_on
      t.integer :due_day_of_month
      t.bigint :paid_amount_cents, null: false, default: 0
      t.bigint :remaining_amount_cents, null: false, default: 0
      t.date :full_due_on
      t.string :status
      t.integer :tenure_months
      t.integer :months_remaining
      t.text :remarks
      t.timestamps null: false
    end

    add_index :card_emi_plans, :account_id
    add_check_constraint :card_emi_plans, "principal_cents >= 0", name: "card_emi_plans_principal_non_negative"
    add_check_constraint :card_emi_plans, "emi_cents >= 0", name: "card_emi_plans_emi_non_negative"
    add_check_constraint :card_emi_plans, "paid_amount_cents >= 0", name: "card_emi_plans_paid_non_negative"
    add_check_constraint :card_emi_plans, "remaining_amount_cents >= 0", name: "card_emi_plans_remaining_non_negative"
    add_check_constraint :card_emi_plans, "due_day_of_month BETWEEN 1 AND 31", name: "card_emi_plans_due_day_range"

    create_table :statements, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.date :cycle_start_on
      t.date :cycle_end_on
      t.date :issue_on
      t.date :due_on
      t.bigint :statement_balance_cents, null: false, default: 0
      t.bigint :min_due_cents, null: false, default: 0
      t.bigint :fees_and_interest_cents, null: false, default: 0
      t.timestamps null: false
    end

    add_index :statements, %i[account_id cycle_end_on], name: "index_statements_on_account_and_cycle_end"
    add_check_constraint :statements, "statement_balance_cents >= 0", name: "statements_balance_non_negative"
    add_check_constraint :statements, "min_due_cents >= 0", name: "statements_min_due_non_negative"
    add_check_constraint :statements, "fees_and_interest_cents >= 0", name: "statements_fees_non_negative"

    create_table :card_transactions, id: :uuid do |t|
      t.references :statement, foreign_key: true, type: :uuid
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.date :posted_on, null: false
      t.string :description
      t.string :category
      t.bigint :amount_cents, null: false
      t.timestamps null: false
    end

    add_index :card_transactions, %i[account_id posted_on], name: "index_card_transactions_on_account_and_posted_on"

    create_table :repayment_schedules, id: :uuid do |t|
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.references :source, polymorphic: true, type: :uuid
      t.date :due_on, null: false
      t.integer :amount_mode, null: false
      t.bigint :amount_due_cents, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.timestamps null: false
    end

    add_index :repayment_schedules, %i[account_id due_on status], name: "index_repayment_schedules_on_account_and_due_on"
    add_check_constraint :repayment_schedules, "amount_due_cents >= 0", name: "repayment_schedules_amount_non_negative"

    create_table :payments, id: :uuid do |t|
      t.references :repayment_schedule, null: false, foreign_key: true, type: :uuid
      t.references :account, null: false, foreign_key: true, type: :uuid
      t.date :paid_on, null: false
      t.bigint :amount_paid_cents, null: false, default: 0
      t.integer :method
      t.string :reference_no
      t.timestamps null: false
    end

    add_index :payments, %i[account_id paid_on]
    add_check_constraint :payments, "amount_paid_cents >= 0", name: "payments_amount_non_negative"

    create_table :expenses, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.date :incurred_on, null: false
      t.string :category, null: false
      t.bigint :amount_cents, null: false, default: 0
      t.text :notes
      t.timestamps null: false
    end

    add_index :expenses, %i[user_id incurred_on]
    add_check_constraint :expenses, "amount_cents >= 0", name: "expenses_amount_non_negative"
  end
end
