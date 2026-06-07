class ExpenseBlueprint < Blueprinter::Base
  identifier :id
  
  fields :amount, :description, :expense_date, :payment_method, :is_recurring
  
  field :category_name do |expense|
    expense.category.name
  end

  field :category_color do |expense|
    expense.category.color
  end

  field :category_icon do |expense|
    expense.category.icon
  end
end
