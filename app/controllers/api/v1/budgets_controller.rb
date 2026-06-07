module Api
  module V1
    class BudgetsController < BaseController
      before_action :set_budget, only: [ :update, :destroy ]

      def index
        month = params[:month].to_i
        year = params[:year].to_i

        budgets = current_user.budgets.includes(:category).for_period(month, year)
        render json: budgets.map { |budget| serialize(budget) }
      end

      def create
        budget = current_user.budgets.build(budget_params)
        budget.save!
        render json: serialize(budget), status: :created
      end

      def update
        @budget.update!(budget_params)
        render json: serialize(@budget)
      end

      def destroy
        @budget.destroy!
        head :no_content
      end

      private

      def set_budget
        @budget = current_user.budgets.find(params[:id])
      end

      def budget_params
        params.permit(:category_id, :month, :year, :amount, :alert_threshold)
      end

      def serialize(budget)
        spent = budget.actual_spent.to_d
        amount = budget.amount.to_d
        percentage = amount.positive? ? (spent / amount * 100).round(1).to_f : 0.0

        budget.as_json.merge(
          "categoryName" => budget.category.name,
          "categoryColor" => budget.category.color,
          "spent" => spent.to_f,
          "percentage" => percentage,
          "remaining" => (amount - spent).to_f
        )
      end
    end
  end
end
