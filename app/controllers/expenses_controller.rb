# frozen_string_literal: true

class ExpensesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_expense, only: %i[show edit update destroy]

  def index
    @expenses = current_user.expenses.order(incurred_on: :desc)
  end

  def show; end

  def new
    @expense = current_user.expenses.new(incurred_on: Date.current)
  end

  def edit; end

  def create
    @expense = current_user.expenses.new(expense_params)
    if @expense.save
      redirect_to @expense, notice: t("expense.flash.created", default: "Expense created.")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @expense.update(expense_params)
      redirect_to @expense, notice: t("expense.flash.updated", default: "Expense updated.")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    redirect_to expenses_url, notice: t("expense.flash.destroyed", default: "Expense removed.")
  end

  private

  def set_expense
    @expense = current_user.expenses.find(params[:id])
  end

  def expense_params
    params.require(:expense).permit(:category, :incurred_on, :amount, :notes)
  end
end
