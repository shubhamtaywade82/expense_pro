class ExpenseBlueprint < Blueprinter::Base
  identifier :id

  fields :amount, :description

  field :expense_date, name: :expenseDate
  field :payment_method, name: :paymentMethod
  field :is_recurring, name: :isRecurring
  field :category_id, name: :categoryId

  field :category_name, name: :categoryName do |expense|
    expense.category.name
  end

  field :category_color, name: :categoryColor do |expense|
    expense.category.color
  end

  field :category_icon, name: :categoryIcon do |expense|
    expense.category.icon
  end
end
