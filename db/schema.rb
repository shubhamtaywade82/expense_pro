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

ActiveRecord::Schema[8.0].define(version: 2026_07_30_140006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.index ["user_id", "broker"], name: "index_broker_credentials_on_user_id_and_broker", unique: true
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
    t.index ["user_id", "broker", "trade_date"], name: "index_trades_on_user_id_and_broker_and_trade_date"
    t.index ["user_id", "exchange_segment"], name: "index_trades_on_user_id_and_exchange_segment"
    t.index ["user_id", "exchange_trade_id"], name: "index_trades_on_user_id_and_exchange_trade_id", unique: true, where: "(exchange_trade_id IS NOT NULL)"
    t.index ["user_id"], name: "index_trades_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "item_type"
    t.string "{:null=>false}"
    t.bigint "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.text "object_changes"
    t.datetime "created_at"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "broker_access_tokens", "users"
  add_foreign_key "broker_credentials", "users"
  add_foreign_key "broker_snapshots", "users"
  add_foreign_key "budgets", "categories"
  add_foreign_key "budgets", "users"
  add_foreign_key "categories", "users"
  add_foreign_key "emi_payments", "loans"
  add_foreign_key "emi_payments", "users"
  add_foreign_key "employments", "users"
  add_foreign_key "expenses", "categories"
  add_foreign_key "expenses", "users"
  add_foreign_key "incomes", "employments"
  add_foreign_key "incomes", "users"
  add_foreign_key "investments", "users"
  add_foreign_key "loans", "categories"
  add_foreign_key "loans", "users"
  add_foreign_key "monthly_bills", "categories"
  add_foreign_key "monthly_bills", "users"
  add_foreign_key "salary_components", "employments"
  add_foreign_key "tax_deductions", "incomes"
  add_foreign_key "trades", "users"
end
