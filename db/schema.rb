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

ActiveRecord::Schema[8.0].define(version: 2026_09_06_180001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "broker_access_tokens", force: :cascade do |t|
    t.string "access_token", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "broker", default: "dhan", null: false
    t.index ["expires_at"], name: "index_broker_access_tokens_on_expires_at"
    t.index ["user_id", "broker"], name: "index_broker_access_tokens_on_user_id_and_broker"
    t.index ["user_id"], name: "index_broker_access_tokens_on_user_id"
  end

  create_table "broker_credentials", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "client_id"
    t.string "token_service_url"
    t.text "token_service_secret"
    t.text "fallback_access_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "broker", default: "dhan", null: false
    t.boolean "auto_import_pnl", default: false, null: false
    t.text "api_key"
    t.text "api_secret"
    t.string "api_passphrase"
    t.string "broker_type", default: "dhanhq", null: false
    t.integer "status", default: 0, null: false
    t.text "access_token"
    t.text "refresh_token"
    t.text "passphrase"
    t.jsonb "config", default: {}, null: false
    t.datetime "token_expires_at"
    t.datetime "last_authenticated_at"
    t.datetime "last_sync_at"
    t.index ["user_id", "broker"], name: "index_broker_credentials_on_user_id_and_broker", unique: true
  end

  create_table "broker_format_profiles", force: :cascade do |t|
    t.bigint "user_id"
    t.string "broker_name"
    t.jsonb "mapping"
    t.jsonb "normalization"
    t.boolean "approved"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_broker_format_profiles_on_user_id"
  end

  create_table "broker_snapshots", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "broker", null: false
    t.string "kind", null: false
    t.string "security_id", null: false
    t.string "trading_symbol"
    t.jsonb "data", default: {}, null: false
    t.datetime "synced_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "broker", "kind", "security_id"], name: "index_broker_snapshots_on_user_broker_kind_security", unique: true
    t.index ["user_id"], name: "index_broker_snapshots_on_user_id"
  end

  create_table "budgets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "category_id", null: false
    t.integer "month", null: false
    t.integer "year", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.integer "alert_threshold", default: 80, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_budgets_on_category_id"
    t.index ["user_id", "category_id", "month", "year"], name: "index_budgets_on_user_category_month_year", unique: true
    t.index ["user_id"], name: "index_budgets_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "category_type", default: "expense", null: false
    t.string "icon", default: "wallet", null: false
    t.string "color", default: "#6366f1", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_default", default: false, null: false
    t.index ["user_id", "category_type"], name: "index_categories_on_user_id_and_category_type"
    t.index ["user_id", "name"], name: "index_categories_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "debt_accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "loan_account_id"
    t.bigint "loan_id"
    t.string "name", null: false
    t.string "lender"
    t.integer "debt_type", default: 0, null: false
    t.integer "classification", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.bigint "original_principal_paise", default: 0, null: false
    t.bigint "current_balance_paise", default: 0, null: false
    t.bigint "monthly_obligation_paise", default: 0
    t.decimal "interest_rate", precision: 6, scale: 3
    t.integer "dpd", default: 0, null: false
    t.boolean "formal_notice", default: false, null: false
    t.date "first_defaulted_on"
    t.date "charged_off_on"
    t.date "last_payment_on"
    t.text "notes"
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "credit_limit_paise", default: 0, null: false
    t.bigint "overdue_amount_paise", default: 0, null: false
    t.integer "statement_day"
    t.integer "due_day"
    t.integer "tenure_months"
    t.integer "remaining_tenure_months"
    t.string "bureau_status"
    t.index ["loan_account_id"], name: "index_debt_accounts_on_loan_account_id"
    t.index ["loan_id"], name: "index_debt_accounts_on_loan_id"
    t.index ["user_id", "classification"], name: "index_debt_accounts_on_user_id_and_classification"
    t.index ["user_id", "debt_type"], name: "index_debt_accounts_on_user_id_and_debt_type"
    t.index ["user_id", "status"], name: "index_debt_accounts_on_user_id_and_status"
    t.index ["user_id"], name: "index_debt_accounts_on_user_id"
  end

  create_table "debt_plans", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "strategy", default: "avalanche", null: false
    t.decimal "monthly_extra", precision: 14, scale: 2, default: "0.0"
    t.string "status", default: "active", null: false
    t.jsonb "loan_priorities", default: []
    t.date "projected_payoff_date"
    t.decimal "total_interest_saved", precision: 14, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_debt_plans_on_status"
    t.index ["strategy"], name: "index_debt_plans_on_strategy"
    t.index ["user_id"], name: "index_debt_plans_on_user_id"
  end

  create_table "debt_snapshots", force: :cascade do |t|
    t.bigint "debt_account_id", null: false
    t.date "recorded_on", null: false
    t.bigint "balance_paise", default: 0, null: false
    t.integer "dpd", default: 0, null: false
    t.string "source", default: "manual"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["debt_account_id", "recorded_on"], name: "index_debt_snapshots_on_debt_account_id_and_recorded_on"
    t.index ["debt_account_id"], name: "index_debt_snapshots_on_debt_account_id"
  end

  create_table "debt_strategies", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.integer "strategy_type", default: 0, null: false
    t.bigint "monthly_allocation_paise", default: 0, null: false
    t.date "target_date"
    t.integer "priority_method", default: 0, null: false
    t.string "status", default: "active", null: false
    t.boolean "is_default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "is_default"], name: "index_debt_strategies_on_user_id_and_is_default"
    t.index ["user_id"], name: "index_debt_strategies_on_user_id"
  end

  create_table "emi_payments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "loan_id", null: false
    t.integer "emi_number", null: false
    t.date "due_date", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.decimal "principal_amount", precision: 14, scale: 2, null: false
    t.decimal "interest_amount", precision: 14, scale: 2, null: false
    t.boolean "is_paid", default: false, null: false
    t.date "paid_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["loan_id", "emi_number"], name: "index_emi_payments_on_loan_id_and_emi_number", unique: true
    t.index ["loan_id"], name: "index_emi_payments_on_loan_id"
    t.index ["user_id"], name: "index_emi_payments_on_user_id"
  end

  create_table "emi_schedules", force: :cascade do |t|
    t.bigint "loan_account_id", null: false
    t.date "due_date"
    t.integer "installment_number"
    t.decimal "opening_balance", precision: 15, scale: 2
    t.decimal "emi_amount", precision: 15, scale: 2
    t.decimal "principal_component", precision: 15, scale: 2
    t.decimal "interest_component", precision: 15, scale: 2
    t.decimal "closing_balance", precision: 15, scale: 2
    t.string "status"
    t.date "paid_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["loan_account_id"], name: "index_emi_schedules_on_loan_account_id"
  end

  create_table "employments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "employer_name", null: false
    t.string "designation"
    t.date "start_date", null: false
    t.date "end_date"
    t.boolean "is_current", default: true
    t.decimal "monthly_ctc", precision: 12, scale: 2
    t.string "pan_of_employer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "fnf_settled_at"
    t.index ["user_id", "employer_name"], name: "index_employments_on_user_id_and_employer_name"
    t.index ["user_id", "is_current"], name: "index_employments_on_user_id_and_is_current"
    t.index ["user_id"], name: "index_employments_on_user_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "category_id", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.string "description"
    t.date "expense_date", null: false
    t.string "payment_method", default: "cash", null: false
    t.boolean "is_recurring", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_expenses_on_category_id"
    t.index ["user_id", "expense_date"], name: "index_expenses_on_user_id_and_expense_date"
    t.index ["user_id"], name: "index_expenses_on_user_id"
  end

  create_table "financial_accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "account_name"
    t.string "institution"
    t.string "account_type"
    t.decimal "balance", precision: 15, scale: 2
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_financial_accounts_on_user_id"
  end

  create_table "income_scenarios", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.integer "scenario_type", default: 5, null: false
    t.date "effective_on", null: false
    t.bigint "monthly_income_paise", default: 0, null: false
    t.bigint "monthly_commitments_paise", default: 0, null: false
    t.bigint "settlement_allocation_paise", default: 0, null: false
    t.bigint "buffer_allocation_paise", default: 0, null: false
    t.boolean "is_active", default: false, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "is_active"], name: "index_income_scenarios_on_user_id_and_is_active"
    t.index ["user_id", "scenario_type"], name: "index_income_scenarios_on_user_id_and_scenario_type"
    t.index ["user_id"], name: "index_income_scenarios_on_user_id"
  end

  create_table "incomes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "source", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.date "income_date", null: false
    t.boolean "is_recurring", default: false, null: false
    t.string "frequency", default: "monthly", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "parent_id"
    t.boolean "is_received", default: true
    t.date "end_date"
    t.boolean "is_custom", default: false, null: false
    t.string "change_reason"
    t.decimal "original_amount", precision: 14, scale: 2
    t.string "income_type", default: "salary", null: false
    t.decimal "gross_amount", precision: 14, scale: 2
    t.decimal "tax_deducted", precision: 14, scale: 2, default: "0.0"
    t.decimal "pf_deducted", precision: 14, scale: 2, default: "0.0"
    t.decimal "other_deductions", precision: 14, scale: 2, default: "0.0"
    t.jsonb "metadata", default: {}
    t.bigint "employment_id"
    t.index ["employment_id"], name: "index_incomes_on_employment_id"
    t.index ["income_type"], name: "index_incomes_on_income_type"
    t.index ["parent_id"], name: "index_incomes_on_parent_id"
    t.index ["user_id", "income_date"], name: "index_incomes_on_user_id_and_income_date"
    t.index ["user_id"], name: "index_incomes_on_user_id"
  end

  create_table "investments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "asset_class", default: "long_term_equity", null: false
    t.string "symbol"
    t.decimal "quantity", precision: 14, scale: 4, default: "1.0", null: false
    t.decimal "buy_price", precision: 14, scale: 2, null: false
    t.decimal "current_price", precision: 14, scale: 2
    t.decimal "sell_price", precision: 14, scale: 2
    t.decimal "invested_amount", precision: 14, scale: 2, null: false
    t.decimal "realized_pnl", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "unrealized_pnl", precision: 14, scale: 2, default: "0.0", null: false
    t.date "purchase_date", null: false
    t.date "sell_date"
    t.string "status", default: "active", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "broker_import_key"
    t.index ["user_id", "asset_class"], name: "index_investments_on_user_id_and_asset_class"
    t.index ["user_id", "broker_import_key"], name: "index_investments_on_user_and_broker_import_key", unique: true, where: "(broker_import_key IS NOT NULL)"
    t.index ["user_id", "status"], name: "index_investments_on_user_id_and_status"
    t.index ["user_id"], name: "index_investments_on_user_id"
  end

  create_table "loan_accounts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name"
    t.string "lender"
    t.string "loan_type"
    t.decimal "principal_amount", precision: 15, scale: 2
    t.decimal "interest_rate", precision: 5, scale: 2
    t.integer "tenure_months"
    t.decimal "emi_amount", precision: 15, scale: 2
    t.date "start_date"
    t.string "status"
    t.decimal "outstanding_principal", precision: 15, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "rate_revisions", default: []
    t.jsonb "disbursements", default: []
    t.jsonb "metadata", default: {}
    t.index ["user_id"], name: "index_loan_accounts_on_user_id"
  end

  create_table "loans", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "category_id", null: false
    t.string "name", null: false
    t.string "lender"
    t.decimal "principal_amount", precision: 14, scale: 2, null: false
    t.decimal "interest_rate", precision: 6, scale: 3, null: false
    t.integer "tenure_months", null: false
    t.date "start_date", null: false
    t.string "loan_type", default: "personal", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "occupancy", default: "self_occupied"
    t.index ["category_id"], name: "index_loans_on_category_id"
    t.index ["user_id"], name: "index_loans_on_user_id"
  end

  create_table "monthly_bills", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "category_id", null: false
    t.string "name", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.integer "due_date", null: false
    t.integer "reminder_days", default: 3, null: false
    t.text "notes"
    t.boolean "is_paid", default: false, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_monthly_bills_on_category_id"
    t.index ["user_id", "is_active"], name: "index_monthly_bills_on_user_id_and_is_active"
    t.index ["user_id"], name: "index_monthly_bills_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "notifiable_type"
    t.bigint "notifiable_id"
    t.string "subject", null: false
    t.text "message", null: false
    t.string "category", default: "info", null: false
    t.boolean "read", default: false, null: false
    t.boolean "archived", default: false, null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "viewed_at", precision: nil
    t.datetime "read_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_notifications_on_category"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["payload"], name: "index_notifications_on_payload", using: :gin
    t.index ["user_id", "archived"], name: "index_notifications_on_user_id_and_archived"
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at", order: { created_at: :desc }
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "prepayments", force: :cascade do |t|
    t.bigint "loan_account_id", null: false
    t.decimal "amount", precision: 15, scale: 2
    t.date "date"
    t.string "impact"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["loan_account_id"], name: "index_prepayments_on_loan_account_id"
  end

  create_table "salary_components", force: :cascade do |t|
    t.bigint "employment_id", null: false
    t.string "component_type", null: false
    t.string "component_label"
    t.decimal "monthly_amount", precision: 12, scale: 2, default: "0.0"
    t.boolean "is_taxable", default: true
    t.boolean "is_exempt_under_80c", default: false
    t.decimal "hra_rent_paid", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employment_id", "component_type"], name: "index_salary_components_on_employment_id_and_component_type"
    t.index ["employment_id"], name: "index_salary_components_on_employment_id"
  end

  create_table "settlement_cases", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "debt_account_id", null: false
    t.date "started_on", null: false
    t.bigint "original_claim_paise", default: 0, null: false
    t.bigint "current_claim_paise", default: 0, null: false
    t.integer "target_min_percentage", default: 20, null: false
    t.integer "target_max_percentage", default: 45, null: false
    t.decimal "service_fee_percentage", precision: 5, scale: 2, default: "15.0", null: false
    t.decimal "gst_percentage", precision: 5, scale: 2, default: "18.0", null: false
    t.bigint "monthly_contribution_paise", default: 0, null: false
    t.integer "eligibility_threshold_percentage", default: 50, null: false
    t.integer "status", default: 0, null: false
    t.integer "stage", default: 4, null: false
    t.integer "priority", default: 1, null: false
    t.date "closed_on"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["debt_account_id"], name: "index_settlement_cases_on_debt_account_id"
    t.index ["user_id", "stage"], name: "index_settlement_cases_on_user_id_and_stage"
    t.index ["user_id", "status"], name: "index_settlement_cases_on_user_id_and_status"
    t.index ["user_id"], name: "index_settlement_cases_on_user_id"
  end

  create_table "settlement_contributions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "settlement_case_id", null: false
    t.date "contributed_on", null: false
    t.bigint "amount_paise", default: 0, null: false
    t.string "source", default: "salary"
    t.string "reference"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["settlement_case_id", "contributed_on"], name: "idx_settl_contrib_case_on_date"
    t.index ["settlement_case_id"], name: "index_settlement_contributions_on_settlement_case_id"
    t.index ["user_id", "contributed_on"], name: "index_settlement_contributions_on_user_id_and_contributed_on"
    t.index ["user_id"], name: "index_settlement_contributions_on_user_id"
  end

  create_table "settlement_documents", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "settlement_case_id", null: false
    t.integer "document_type", default: 6, null: false
    t.string "title", null: false
    t.integer "status", default: 0, null: false
    t.jsonb "extracted", default: {}, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["settlement_case_id", "document_type"], name: "idx_settl_docs_case_on_type"
    t.index ["settlement_case_id"], name: "index_settlement_documents_on_settlement_case_id"
    t.index ["user_id"], name: "index_settlement_documents_on_user_id"
  end

  create_table "settlement_offers", force: :cascade do |t|
    t.bigint "settlement_case_id", null: false
    t.date "offered_on", null: false
    t.bigint "claim_amount_paise", default: 0, null: false
    t.decimal "settlement_percentage", precision: 5, scale: 2, default: "0.0", null: false
    t.bigint "settlement_amount_paise", default: 0, null: false
    t.bigint "service_fee_paise", default: 0, null: false
    t.bigint "gst_paise", default: 0, null: false
    t.bigint "total_amount_paise", default: 0, null: false
    t.date "valid_until"
    t.integer "status", default: 0, null: false
    t.date "accepted_on"
    t.string "reference_number"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["settlement_case_id", "status"], name: "index_settlement_offers_on_settlement_case_id_and_status"
    t.index ["settlement_case_id"], name: "index_settlement_offers_on_settlement_case_id"
  end

  create_table "settlement_payments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "settlement_case_id", null: false
    t.bigint "settlement_offer_id"
    t.date "paid_on", null: false
    t.bigint "settlement_amount_paise", default: 0, null: false
    t.bigint "service_fee_paise", default: 0, null: false
    t.bigint "gst_paise", default: 0, null: false
    t.bigint "total_paid_paise", default: 0, null: false
    t.string "payment_mode", default: "neft"
    t.string "reference_number"
    t.boolean "synced_to_expenses", default: false, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["settlement_case_id", "paid_on"], name: "index_settlement_payments_on_settlement_case_id_and_paid_on"
    t.index ["settlement_case_id"], name: "index_settlement_payments_on_settlement_case_id"
    t.index ["settlement_offer_id"], name: "index_settlement_payments_on_settlement_offer_id"
    t.index ["user_id"], name: "index_settlement_payments_on_user_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tax_deductions", force: :cascade do |t|
    t.bigint "income_id", null: false
    t.string "deduction_type", null: false
    t.decimal "tds_amount", precision: 12, scale: 2, null: false
    t.date "paid_on"
    t.string "remarks"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["income_id", "deduction_type"], name: "index_tax_deductions_on_income_id_and_deduction_type"
    t.index ["income_id"], name: "index_tax_deductions_on_income_id"
  end

  create_table "tax_documents", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "financial_year"
    t.string "document_type"
    t.integer "status"
    t.integer "source"
    t.jsonb "extracted_data"
    t.jsonb "reconciliation"
    t.jsonb "metadata"
    t.datetime "verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_tax_documents_on_user_id"
  end

  create_table "trades", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "broker", default: "dhan", null: false
    t.string "exchange_trade_id"
    t.string "order_id"
    t.string "exchange_order_id"
    t.string "dhan_client_id"
    t.string "transaction_type", null: false
    t.string "exchange_segment", null: false
    t.string "product_type"
    t.string "order_type"
    t.string "trading_symbol"
    t.string "custom_symbol"
    t.string "security_id"
    t.string "isin"
    t.string "instrument"
    t.decimal "traded_quantity", precision: 14, scale: 4
    t.decimal "traded_price", precision: 14, scale: 2
    t.date "expiry_date"
    t.string "option_type"
    t.decimal "strike_price", precision: 14, scale: 2
    t.decimal "sebi_tax", precision: 12, scale: 2, default: "0.0"
    t.decimal "stt", precision: 12, scale: 2, default: "0.0"
    t.decimal "brokerage", precision: 12, scale: 2, default: "0.0"
    t.decimal "gst", precision: 12, scale: 2, default: "0.0"
    t.decimal "exchange_charges", precision: 12, scale: 2, default: "0.0"
    t.decimal "stamp_duty", precision: 12, scale: 2, default: "0.0"
    t.jsonb "raw_data", default: {}
    t.datetime "trade_date"
    t.datetime "exchange_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "broker_type", default: "securities", null: false
    t.index ["user_id", "broker", "trade_date"], name: "index_trades_on_user_id_and_broker_and_trade_date"
    t.index ["user_id", "exchange_segment"], name: "index_trades_on_user_id_and_exchange_segment"
    t.index ["user_id", "exchange_trade_id"], name: "index_trades_on_user_id_and_exchange_trade_id", unique: true, where: "(exchange_trade_id IS NOT NULL)"
    t.index ["user_id"], name: "index_trades_on_user_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "financial_account_id", null: false
    t.bigint "category_id"
    t.bigint "loan_account_id"
    t.string "taggable_type"
    t.bigint "taggable_id"
    t.string "txn_type"
    t.integer "status"
    t.decimal "amount"
    t.datetime "txn_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["financial_account_id"], name: "index_transactions_on_financial_account_id"
    t.index ["loan_account_id"], name: "index_transactions_on_loan_account_id"
    t.index ["taggable_type", "taggable_id"], name: "index_transactions_on_taggable"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "token_revoked_at"
    t.string "persona", default: "mixed", null: false
    t.string "pan"
    t.date "date_of_birth"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["persona"], name: "index_users_on_persona"
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.text "object_changes"
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "broker_access_tokens", "users"
  add_foreign_key "broker_credentials", "users"
  add_foreign_key "broker_format_profiles", "users"
  add_foreign_key "broker_snapshots", "users"
  add_foreign_key "budgets", "categories"
  add_foreign_key "budgets", "users"
  add_foreign_key "categories", "users"
  add_foreign_key "debt_accounts", "loan_accounts"
  add_foreign_key "debt_accounts", "loans"
  add_foreign_key "debt_accounts", "users"
  add_foreign_key "debt_plans", "users"
  add_foreign_key "debt_snapshots", "debt_accounts"
  add_foreign_key "debt_strategies", "users"
  add_foreign_key "emi_payments", "loans"
  add_foreign_key "emi_payments", "users"
  add_foreign_key "emi_schedules", "loan_accounts"
  add_foreign_key "employments", "users"
  add_foreign_key "expenses", "categories"
  add_foreign_key "expenses", "users"
  add_foreign_key "financial_accounts", "users"
  add_foreign_key "income_scenarios", "users"
  add_foreign_key "incomes", "employments"
  add_foreign_key "incomes", "users"
  add_foreign_key "investments", "users"
  add_foreign_key "loan_accounts", "users"
  add_foreign_key "loans", "categories"
  add_foreign_key "loans", "users"
  add_foreign_key "monthly_bills", "categories"
  add_foreign_key "monthly_bills", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "prepayments", "loan_accounts"
  add_foreign_key "salary_components", "employments"
  add_foreign_key "settlement_cases", "debt_accounts"
  add_foreign_key "settlement_cases", "users"
  add_foreign_key "settlement_contributions", "settlement_cases"
  add_foreign_key "settlement_contributions", "users"
  add_foreign_key "settlement_documents", "settlement_cases"
  add_foreign_key "settlement_documents", "users"
  add_foreign_key "settlement_offers", "settlement_cases"
  add_foreign_key "settlement_payments", "settlement_cases"
  add_foreign_key "settlement_payments", "settlement_offers"
  add_foreign_key "settlement_payments", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tax_deductions", "incomes"
  add_foreign_key "tax_documents", "users"
  add_foreign_key "trades", "users"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "financial_accounts"
  add_foreign_key "transactions", "loan_accounts"
  add_foreign_key "transactions", "users"
end
