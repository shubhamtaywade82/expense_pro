# frozen_string_literal: true

module Ai
  class ToolExecutor
    def initialize(user)
      @user = user
    end

    def execute(tool_call)
      case tool_call.name
      when "create_expense"
        create_expense(tool_call.arguments)
      when "pay_bill"
        pay_bill(tool_call.arguments)
      else
        { success: false, message: "Unknown tool" }
      end
    rescue StandardError => e
      { success: false, message: "Error: #{e.message}" }
    end

    private

    def create_expense(args)
      category = resolve_category(args["category_name"])
      expense = @user.expenses.create!(
        amount: args["amount"].to_d,
        category: category,
        payment_method: args["payment_method"],
        expense_date: Date.parse(args["expense_date"] || Date.current.to_s),
        description: args["description"]
      )
      { success: true, message: "Expense logged", expense_id: expense.id, amount: expense.amount.to_s, category: category.name }
    end

    def pay_bill(args)
      bill = @user.monthly_bills.find_by(id: args["bill_id"])
      if bill&.update(is_paid: true)
        { success: true, message: "Bill marked as paid", bill_id: bill.id, name: bill.name }
      else
        { success: false, message: "Bill not found" }
      end
    end

    def resolve_category(name)
      clean_name = name.to_s.strip
      @user.categories.where("name ILIKE ?", clean_name).first ||
        @user.categories.find_by(name: "Other") ||
        @user.categories.create!(name: clean_name, category_type: "expense")
    end
  end
end
