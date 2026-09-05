module Api
  module V1
    class ExpensesController < BaseController
      before_action :set_expense, only: [ :update, :destroy ]

      def index
        scope = current_user.expenses.includes(:category).recent_first

        if params[:month].present? && params[:year].present?
          scope = scope.for_month(params[:month].to_i, params[:year].to_i)
        end

        scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
        scope = scope.search(params[:search]) if params[:search].present?

        @pagy, @expenses = pagy(scope)

        render json: {
          data: @expenses.map(&:as_json),
          meta: {
            page: @pagy.page,
            per_page: @pagy.limit,
            total: @pagy.count,
            pages: @pagy.pages
          }
        }
      end

      def create
        expense = current_user.expenses.build(expense_params)
        expense.save!
        render json: expense.as_json, status: :created
      end

      def update
        @expense.update!(expense_params)
        render json: @expense.as_json
      end

      def destroy
        @expense.destroy!
        head :no_content
      end

      private

      def set_expense
        @expense = current_user.expenses.find(params[:id])
      end

      def expense_params
        params.permit(:category_id, :amount, :description, :expense_date, :payment_method, :is_recurring)
      end
    end
  end
end
