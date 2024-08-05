class CreditCardsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_credit_card, only: %i[show edit update destroy]

  def index
    @credit_cards = current_user.credit_cards
  end

  def show; end

  def new
    @credit_card = current_user.credit_cards.new
  end

  def edit; end

  def create
    @credit_card = current_user.credit_cards.new(credit_card_params)
    if @credit_card.save
      redirect_to @credit_card, notice: t("credit_card.flash.created")
    else
      render :new
    end
  end

  def update
    if @credit_card.update(credit_card_params)
      redirect_to @credit_card, notice: t("credit_card.flash.updated")
    else
      render :edit
    end
  end

  def destroy
    @credit_card.destroy
    redirect_to credit_cards_url, notice: t("credit_card.flash.destroyed")
  end

  private

  def set_credit_card
    @credit_card = current_user.credit_cards.find(params[:id])
  end

  def credit_card_params
    params.require(:credit_card).permit(
      :name, :card_type, :expiry_date, :statement_date, :payment_due_date,
      :reminder, :last_four_digits, :description, :additional_notes, :has_annual_fee
    )
  end
end
