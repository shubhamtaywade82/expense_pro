# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_08_15_130000) do
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "institution_id"
    t.integer "account_kind", default: 0, null: false
    t.string "external_ref"
    t.date "opened_on"
    t.date "closed_on"
    t.integer "status", default: 0, null: false
    t.decimal "current_outstanding", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "current_limit", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "current_utilization", precision: 8, scale: 4, default: "0.0", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_kind"], name: "index_accounts_on_account_kind"
    t.index ["institution_id"], name: "index_accounts_on_institution_id"
    t.index ["status"], name: "index_accounts_on_status"
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "card_emi_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "plan_name"
    t.decimal "principal", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "emi", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "roi", precision: 6, scale: 3
    t.date "start_on"
    t.integer "due_day_of_month"
    t.decimal "paid_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "remaining_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.date "full_due_on"
    t.string "status"
    t.integer "tenure_months"
    t.integer "months_remaining"
    t.text "remarks"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_card_emi_plans_on_account_id"
  end

  create_table "card_transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "statement_id"
    t.uuid "account_id", null: false
    t.date "posted_on", null: false
    t.string "description"
    t.string "category"
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_card_transactions_on_account_id"
    t.index ["account_id", "posted_on"], name: "index_card_transactions_on_account_and_posted_on"
    t.index ["statement_id"], name: "index_card_transactions_on_statement_id"
  end

  create_table "credit_card_details", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "card_name"
    t.integer "statement_day_of_month"
    t.integer "due_day_of_month"
    t.decimal "outstanding", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "bill_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "limit_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "utilization", precision: 8, scale: 4, default: "0.0", null: false
    t.decimal "paid_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "remaining_due", precision: 15, scale: 2, default: "0.0", null: false
    t.date "full_due_on"
    t.string "status"
    t.decimal "apr", precision: 6, scale: 3
    t.decimal "min_due_rate", precision: 6, scale: 3, default: "5.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_credit_card_details_on_account_id", unique: true
  end

  create_table "expenses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.date "incurred_on", null: false
    t.string "category", null: false
    t.decimal "amount", precision: 15, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_expenses_on_user_id"
    t.index ["user_id", "incurred_on"], name: "index_expenses_on_user_id_and_incurred_on"
  end

  create_table "institutions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.integer "kind", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_institutions_on_name", unique: true
  end

  create_table "loan_details", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "loan_type"
    t.decimal "principal", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "outstanding", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "emi", precision: 15, scale: 2
    t.decimal "roi", precision: 6, scale: 3
    t.date "start_on"
    t.integer "due_day_of_month"
    t.decimal "paid_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "remaining_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.date "full_due_on"
    t.string "status"
    t.integer "tenure_months"
    t.integer "months_remaining"
    t.decimal "total_interest_paid", precision: 15, scale: 2, default: "0.0", null: false
    t.text "remarks"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_loan_details_on_account_id", unique: true
  end

  create_table "payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "repayment_schedule_id", null: false
    t.uuid "account_id", null: false
    t.date "paid_on", null: false
    t.decimal "amount_paid", precision: 15, scale: 2, default: "0.0", null: false
    t.integer "method"
    t.string "reference_no"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_payments_on_account_id"
    t.index ["account_id", "paid_on"], name: "index_payments_on_account_id_and_paid_on"
    t.index ["repayment_schedule_id"], name: "index_payments_on_repayment_schedule_id"
  end

  create_table "repayment_schedules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.string "source_type"
    t.uuid "source_id"
    t.date "due_on", null: false
    t.integer "amount_mode", null: false
    t.decimal "amount_due", precision: 15, scale: 2, default: "0.0", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_repayment_schedules_on_account_id"
    t.index ["account_id", "due_on", "status"], name: "index_repayment_schedules_on_account_and_due_on"
    t.index ["source_type", "source_id"], name: "index_repayment_schedules_on_source"
  end

  create_table "statements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "account_id", null: false
    t.date "cycle_start_on"
    t.date "cycle_end_on"
    t.date "issue_on"
    t.date "due_on"
    t.decimal "statement_balance", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "min_due", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "fees_and_interest", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_statements_on_account_id"
    t.index ["account_id", "cycle_end_on"], name: "index_statements_on_account_and_cycle_end"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "full_name", null: false
    t.string "time_zone", default: "Asia/Kolkata", null: false
    t.decimal "monthly_income", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_check_constraint "accounts", "current_limit >= 0", name: "accounts_limit_non_negative"
  add_check_constraint "accounts", "current_outstanding >= 0", name: "accounts_outstanding_non_negative"
  add_check_constraint "accounts", "current_utilization >= 0", name: "accounts_utilization_non_negative"
  add_check_constraint "card_emi_plans", "due_day_of_month BETWEEN 1 AND 31", name: "card_emi_plans_due_day_range"
  add_check_constraint "card_emi_plans", "emi >= 0", name: "card_emi_plans_emi_non_negative"
  add_check_constraint "card_emi_plans", "paid_amount >= 0", name: "card_emi_plans_paid_non_negative"
  add_check_constraint "card_emi_plans", "principal >= 0", name: "card_emi_plans_principal_non_negative"
  add_check_constraint "card_emi_plans", "remaining_amount >= 0", name: "card_emi_plans_remaining_non_negative"
  add_check_constraint "credit_card_details", "bill_amount >= 0", name: "credit_card_details_bill_non_negative"
  add_check_constraint "credit_card_details", "due_day_of_month BETWEEN 1 AND 31", name: "credit_card_details_due_day_range"
  add_check_constraint "credit_card_details", "limit_amount >= 0", name: "credit_card_details_limit_non_negative"
  add_check_constraint "credit_card_details", "outstanding >= 0", name: "credit_card_details_outstanding_non_negative"
  add_check_constraint "credit_card_details", "paid_amount >= 0", name: "credit_card_details_paid_non_negative"
  add_check_constraint "credit_card_details", "remaining_due >= 0", name: "credit_card_details_remaining_non_negative"
  add_check_constraint "credit_card_details", "statement_day_of_month BETWEEN 1 AND 31", name: "credit_card_details_statement_day_range"
  add_check_constraint "credit_card_details", "utilization >= 0", name: "credit_card_details_utilization_non_negative"
  add_check_constraint "expenses", "amount >= 0", name: "expenses_amount_non_negative"
  add_check_constraint "loan_details", "due_day_of_month BETWEEN 1 AND 31", name: "loan_details_due_day_range"
  add_check_constraint "loan_details", "outstanding >= 0", name: "loan_details_outstanding_non_negative"
  add_check_constraint "loan_details", "paid_amount >= 0", name: "loan_details_paid_non_negative"
  add_check_constraint "loan_details", "principal >= 0", name: "loan_details_principal_non_negative"
  add_check_constraint "loan_details", "remaining_amount >= 0", name: "loan_details_remaining_non_negative"
  add_check_constraint "loan_details", "total_interest_paid >= 0", name: "loan_details_interest_non_negative"
  add_check_constraint "payments", "amount_paid >= 0", name: "payments_amount_non_negative"
  add_check_constraint "repayment_schedules", "amount_due >= 0", name: "repayment_schedules_amount_non_negative"
  add_check_constraint "users", "monthly_income >= 0", name: "users_monthly_income_non_negative"

  add_foreign_key "accounts", "institutions"
  add_foreign_key "accounts", "users"
  add_foreign_key "card_emi_plans", "accounts"
  add_foreign_key "card_transactions", "accounts"
  add_foreign_key "card_transactions", "statements"
  add_foreign_key "credit_card_details", "accounts"
  add_foreign_key "expenses", "users"
  add_foreign_key "loan_details", "accounts"
  add_foreign_key "payments", "accounts"
  add_foreign_key "payments", "repayment_schedules"
  add_foreign_key "repayment_schedules", "accounts"
  add_foreign_key "statements", "accounts"
end
