module Api
  module V1
    class BudgetsController < BaseController
      before_action :set_budget, only: [ :update, :destroy ]

      def index
        month = params[:month].to_i
        year = params[:year].to_i

        budgets = current_user.budgets.includes(:category).for_period(month, year).to_a

        spent_by_category = current_user.expenses
          .where(category_id: budgets.map(&:category_id))
          .for_month(month, year)
          .group(:category_id)
          .sum(:amount)

        bill_category_ids = budgets.select { |b| b.category.category_type == "bill" }.map(&:category_id)
        if bill_category_ids.any?
          bill_spent = current_user.monthly_bills
            .where(category_id: bill_category_ids, is_paid: true)
            .group(:category_id)
            .sum(:amount)
          bill_spent.each { |cid, amt| spent_by_category[cid] = (spent_by_category[cid] || 0) + amt }
        end

        render json: budgets.map { |budget| serialize(budget, spent: spent_by_category[budget.category_id] || 0) }
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

      def serialize(budget, spent: budget.actual_spent)
        spent = spent.to_d
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
