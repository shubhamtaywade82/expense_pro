# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!

  PERIODS = %i[day week month all].freeze

  def index
    @periods = PERIODS
    @due_totals = totals_for(:total_due_in_period)
    @paid_totals = totals_for(:total_paid_in_period)
    @expense_totals = totals_for(:total_expenses_in_period)
    @card_utilization_ratio = current_user.card_utilization_ratio
  end

  private

  def totals_for(method_name)
    PERIODS.index_with { |period| current_user.public_send(method_name, period) }
  end
end
