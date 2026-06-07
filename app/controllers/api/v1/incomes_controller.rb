module Api
  module V1
    class IncomesController < BaseController
      before_action :set_income, only: [ :update, :destroy ]

      def index
        scope = current_user.incomes.recent_first

        if params[:month].present? && params[:year].present?
          scope = scope.for_month(params[:month].to_i, params[:year].to_i)
        end

        render json: scope
      end

      def summary
        month = params[:month].to_i
        year = params[:year].to_i
        scope = current_user.incomes.for_month(month, year)

        render json: { total: scope.sum(:amount).to_s, count: scope.count }
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

      private

      def set_income
        @income = current_user.incomes.find(params[:id])
      end

      def income_params
        params.permit(:source, :amount, :income_date, :is_recurring, :frequency, :notes)
      end
    end
  end
end
