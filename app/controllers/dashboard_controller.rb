class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @total_income = current_user.incomes.sum(:amount)
    @total_expense = current_user.expenses.sum(:amount)
    @balance = @total_income - @total_expense
    @recent_incomes = current_user.incomes.order(created_at: :desc).limit(5)
    @recent_expenses = current_user.expenses.order(created_at: :desc).limit(5)
  end
end
