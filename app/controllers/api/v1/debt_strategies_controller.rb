module Api
  module V1
    # Strategy layer: normal repayment vs settlement vs hybrid, with the
    # monthly allocation and priority method that drive queue + forecast.
    class DebtStrategiesController < BaseController
      before_action :set_strategy, only: %i[update destroy set_default]

      def index
        render_camel_json current_user.debt_strategies.default_first.map { |s| payload(s) }
      end

      def create
        strategy = current_user.debt_strategies.create!(strategy_params)
        strategy.set_default! if ActiveModel::Type::Boolean.new.cast(params[:is_default])
        render_camel_json payload(strategy), status: :created
      end

      def update
        @strategy.update!(strategy_params)
        render_camel_json payload(@strategy)
      end

      def destroy
        @strategy.destroy!
        head :no_content
      end

      # PATCH /api/v1/debt_strategies/:id/set_default
      def set_default
        @strategy.set_default!
        render_camel_json payload(@strategy)
      end

      private

      def set_strategy
        @strategy = current_user.debt_strategies.find(params[:id])
      end

      def strategy_params
        permitted = params.permit(:name, :strategy_type, :priority_method, :monthly_allocation, :target_date, :status, :is_default)
        permitted[:monthly_allocation_paise] = (permitted.delete(:monthly_allocation).to_f * 100).round if permitted.key?(:monthly_allocation)
        permitted[:target_date] = Date.parse(permitted[:target_date]) if permitted[:target_date].present?
        permitted
      rescue Date::Error
        raise ActionController::BadRequest, "target_date must be YYYY-MM-DD"
      end

      def payload(strategy)
        strategy.as_json.merge(
          "monthlyAllocation" => strategy.monthly_allocation.to_f
        )
      end
    end
  end
end
