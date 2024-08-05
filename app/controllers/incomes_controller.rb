class IncomesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_income, only: %i[show edit update destroy]

  def index
    @incomes = current_user.incomes
  end

  def show; end

  def new
    @income = current_user.incomes.new
  end

  def edit; end

  def create
    @income = current_user.incomes.new(income_params)
    if @income.save
      redirect_to @income, notice: t("income.flash.created")
    else
      render :new
    end
  end

  def update
    if @income.update(income_params)
      redirect_to @income, notice: t("income.flash.updated")
    else
      render :edit
    end
  end

  def destroy
    @income.destroy
    redirect_to incomes_url, notice: t("income.flash.destroyed")
  end

  private

  def set_income
    @income = current_user.incomes.find(params[:id])
  end

  def income_params
    params.require(:income).permit(:source, :description, :amount, :frequency)
  end
end
