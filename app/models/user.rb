class User < ApplicationRecord
  has_secure_password

  has_many :categories, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :incomes, dependent: :destroy
  has_many :monthly_bills, dependent: :destroy
  has_many :loans, dependent: :destroy
  has_many :emi_payments, dependent: :destroy
  has_many :budgets, dependent: :destroy
  has_many :investments, dependent: :destroy
  has_many :broker_snapshots, dependent: :destroy
  has_many :trades, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true

  DEFAULT_CATEGORIES = [
    { name: "Groceries", category_type: "expense", icon: "shopping-cart", color: "#22c55e" },
    { name: "Travel", category_type: "expense", icon: "car", color: "#6366f1" },
    { name: "Dining Out", category_type: "expense", icon: "utensils", color: "#ec4899" },
    { name: "Entertainment", category_type: "expense", icon: "film", color: "#8b5cf6" },
    { name: "Health", category_type: "expense", icon: "heart-pulse", color: "#ef4444" },
    { name: "Shopping", category_type: "expense", icon: "shopping-bag", color: "#06b6d4" },
    { name: "Other", category_type: "expense", icon: "more-horizontal", color: "#6b7280" },
    { name: "Salary", category_type: "income", icon: "wallet", color: "#22c55e" },
    { name: "Freelance", category_type: "income", icon: "briefcase", color: "#6366f1" },
    { name: "Electricity", category_type: "bill", icon: "zap", color: "#f59e0b" },
    { name: "Internet & Phone", category_type: "bill", icon: "wifi", color: "#0ea5e9" },
    { name: "Rent", category_type: "bill", icon: "home", color: "#84cc16" },
    { name: "Home Loan", category_type: "loan", icon: "landmark", color: "#6366f1" },
    { name: "Vehicle Loan", category_type: "loan", icon: "car", color: "#f97316" },
    { name: "Personal Loan", category_type: "loan", icon: "wallet", color: "#a855f7" },
    { name: "Loan EMI", category_type: "emi", icon: "calendar-clock", color: "#ef4444" }
  ].freeze

  after_create :seed_default_categories

  private

  def seed_default_categories
    DEFAULT_CATEGORIES.each { |attrs| categories.create!(attrs.merge(is_default: true)) }
  end
end
