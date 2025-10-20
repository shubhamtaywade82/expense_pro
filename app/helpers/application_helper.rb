# frozen_string_literal: true

module ApplicationHelper
  # @param amount [BigDecimal, Numeric, nil] amount stored in rupees.
  # @return [String] formatted INR value.
  def formatted_amount(amount)
    number_to_currency(amount || 0, unit: "₹")
  end
end
