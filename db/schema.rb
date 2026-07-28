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

ActiveRecord::Schema[8.0].define(version: 2026_07_28_133002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "dhan_access_tokens", force: :cascade do |t|
    t.string "access_token", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_dhan_access_tokens_on_expires_at"
    t.index ["user_id"], name: "index_dhan_access_tokens_on_user_id"
  end

  create_table "dhan_credentials", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "client_id"
    t.string "token_service_url"
    t.text "token_service_secret"
    t.text "fallback_access_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_dhan_credentials_on_user_id", unique: true
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
    t.index ["user_id", "asset_class"], name: "index_investments_on_user_id_and_asset_class"
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

  add_foreign_key "budgets", "categories"
  add_foreign_key "budgets", "users"
  add_foreign_key "categories", "users"
  add_foreign_key "dhan_access_tokens", "users"
  add_foreign_key "dhan_credentials", "users"
  add_foreign_key "emi_payments", "loans"
  add_foreign_key "emi_payments", "users"
  add_foreign_key "expenses", "categories"
  add_foreign_key "expenses", "users"
  add_foreign_key "incomes", "users"
  add_foreign_key "investments", "users"
  add_foreign_key "loans", "categories"
  add_foreign_key "loans", "users"
  add_foreign_key "monthly_bills", "categories"
  add_foreign_key "monthly_bills", "users"
end
