# frozen_string_literal: true

# Global money configuration for ExpensePro.
#
# All monetary amounts in the debt clearance domain (debt accounts,
# settlement cases, offers, contributions, payments, income scenarios)
# are stored as integer paise in `*_paise` bigint columns and exposed
# to Ruby as Money objects via the `monetize` macro:
#
#   monetize :claim_amount_paise, as: :claim_amount
#
# The rest of the application (loans, expenses, incomes, ...) keeps its
# existing decimal(14,2) major-unit columns; convert at the boundary
# with `value.to_money(:inr)` when a Money object is needed there.
MoneyRails.configure do |config|
  config.default_currency = :inr

  # Fees/GST math must round half up to the nearest paisa, consistently.
  config.rounding_mode = BigDecimal::ROUND_HALF_UP

  # Money#format defaults we rely on in services and notifications.
  # ₹1,00,000.00 style grouping comes from the :inr currency definition.
  config.locale_backend = :currency
end
