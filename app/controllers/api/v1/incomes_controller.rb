module Api
  module V1
    class IncomesController < BaseController
      before_action :set_income, only: [ :update, :destroy, :toggle_received ]

      def index
        if params[:month].present? && params[:year].present?
          start_date = Date.new(params[:year].to_i, params[:month].to_i, 1)
          incomes = IncomeProjectionService.new(current_user, start_date, start_date.end_of_month).call
          render json: incomes
        else
          render json: current_user.incomes.recent_first
        end
      end

      def summary
        start_date = Date.new(params[:year].to_i, params[:month].to_i, 1)
        incomes = IncomeProjectionService.new(current_user, start_date, start_date.end_of_month).call

        total = incomes.sum { |inc| inc.amount.to_f }
        render json: { total: total.to_s, count: incomes.count }
      end

      def create
        income = current_user.incomes.build(income_params)
        income.save!
        render json: income, status: :created
      end

      def update
        @income.update!(income_params)
        render json: @income
      end

      def destroy
        @income.destroy!
        head :no_content
      end

      def toggle_received
        @income.update!(is_received: !@income.is_received)
        render json: @income
      end

      private

      def set_income
        @income = current_user.incomes.find(params[:id])
      end

      def income_params
        params.permit(:source, :amount, :income_date, :is_recurring, :frequency, :notes, :parent_id, :is_received)
      end
    end
  end
end
