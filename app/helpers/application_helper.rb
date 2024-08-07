module ApplicationHelper
  def formatted_amount(amount)
    user_currency = current_user.currency
    Money.new(amount * 100, user_currency).format
  end
end
