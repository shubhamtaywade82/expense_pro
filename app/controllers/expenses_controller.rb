class ExpensesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_expense, only: %i[show edit update destroy]

  def index
    @expenses = current_user.expenses
  end

  def show; end

  def new
    @expense = current_user.expenses.new
    @credit_cards = current_user.credit_cards
  end

  def edit
    @credit_cards = current_user.credit_cards
  end

  def create
    @expense = current_user.expenses.new(expense_params)
    if @expense.save
      redirect_to @expense, notice: t("expense.flash.created")
    else
      @credit_cards = current_user.credit_cards
      render :new
    end
  end

  def update
    if @expense.update(expense_params)
      redirect_to @expense, notice: t("expense.flash.updated")
    else
      @credit_cards = current_user.credit_cards
      render :edit
    end
  end

  def destroy
    @expense.destroy
    redirect_to expenses_url, notice: t("expense.flash.destroyed")
  end

  private

  def set_expense
    @expense = current_user.expenses.find(params[:id])
  end

  def expense_params
    params.require(:expense).permit(:category, :description, :amount, :payment_method,
                                    :expense_type, :payment_type, :credit_card_id)
  end
end
