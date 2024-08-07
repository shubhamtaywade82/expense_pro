class UsersController < ApplicationController
  before_action :authenticate_user!

  def update_currency
    if current_user.update(currency_params)
      redirect_back fallback_location: root_path, notice: "Currency updated successfully."
    else
      redirect_back fallback_location: root_path, alert: "Failed to update currency."
    end
  end

  private

  def currency_params
    params.require(:user).permit(:currency)
  end
end
