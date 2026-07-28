# frozen_string_literal: true

module Ai
  class PromptBuilder
    def initialize(user)
      @user = user
    end

    def build
      dashboard = DashboardService.new(@user, month: Date.current.month, year: Date.current.year).overview

      <<~SYSTEM
        You are ExpensePro AI, a premium personal finance assistant.
        Use the tools provided to take actions like logging expenses or paying bills.

        Current Local Time: #{Time.current.strftime("%A, %B %d, %Y, %I:%M %p")}

        User's Current Financial Data (#{Time.current.strftime("%B %Y")}):
        - Total Income: ₹#{dashboard.dig(:income, :total)} (#{dashboard.dig(:income, :received)} received, #{dashboard.dig(:income, :expected)} expected/projected)
        - Total Expenses: ₹#{dashboard.dig(:expenses, :total)}
        - Monthly Bills: ₹#{dashboard.dig(:bills, :total)} total (#{dashboard.dig(:bills, :paid)} paid, #{dashboard.dig(:bills, :unpaid)} pending)
        - Loan EMIs: ₹#{dashboard.dig(:emis, :total)}
        - Net Savings (This Month): ₹#{calculate_net_savings(dashboard)}

        Overall / Life-to-Date Metrics:
        - Total Income to Date: ₹#{dashboard.dig(:overall, :totalIncome)}
        - Total Expenses to Date: ₹#{dashboard.dig(:overall, :totalExpense)}
        - Total Loan EMIs Paid: ₹#{dashboard.dig(:overall, :totalEmiPaid)}
        - Net Balance (Life-to-Date Savings): ₹#{dashboard.dig(:overall, :netBalance)}

        Active Categories:
        #{formatted_categories}

        Active Monthly Bills:
        #{formatted_bills}

        Recent Expenses:
        #{formatted_expenses}

        Instructions:
        1. Use 'create_expense' for spending.
        2. Use 'pay_bill' with the correct ID for paying specific bills.
        3. Do NOT hallucinate tools. All finance data is provided here; answer questions directly.
        4. DO NOT call tools like 'get_net_savings', 'get_income', 'get_expenses', or 'get_bills'. This information is ALREADY in this prompt.
        5. Only call 'pay_bill' if explicitly asked to mark it as paid.
      SYSTEM
    end

    private

    def calculate_net_savings(dashboard)
      dashboard.dig(:income, :total).to_d -
        dashboard.dig(:expenses, :total).to_d -
        dashboard.dig(:bills, :total).to_d -
        dashboard.dig(:emis, :total).to_d
    end

    def formatted_categories
      @user.categories.map { |c| "- #{c.name} (#{c.category_type})" }.join("\n")
    end

    def formatted_bills
      @user.monthly_bills.active.map { |b| "- ID: #{b.id}, Name: #{b.name}, Amount: ₹#{b.amount}, Paid: #{b.is_paid ? 'Yes' : 'No'}" }.join("\n")
    end

    def formatted_expenses
      @user.expenses.includes(:category).recent_first.limit(5).map { |e| "- #{e.expense_date}: ₹#{e.amount} for #{e.description || e.category.name}" }.join("\n")
    end
  end
end
