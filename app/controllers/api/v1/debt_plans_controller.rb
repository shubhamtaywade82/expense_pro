module Api
  module V1
    class DebtPlansController < BaseController
      def summary
        render json: DebtPlanningService.new(current_user).debt_summary
      end

      def simulate
        result = DebtPlanningService.new(current_user).simulate_payoff(
          strategy: params[:strategy] || "avalanche",
          extra_monthly: params[:extra_monthly].to_f
        )
        render json: result
      end

      def create
        plan = current_user.debt_plans.create!(
          name: params[:name],
          strategy: params[:strategy] || "avalanche",
          monthly_extra: params[:monthly_extra] || 0,
          status: "active"
        )

        simulation = DebtPlanningService.new(current_user).simulate_payoff(
          strategy: plan.strategy,
          extra_monthly: plan.monthly_extra.to_f
        )

        if simulation[:error]
          plan.update(projected_payoff_date: nil)
        else
          plan.update(
            projected_payoff_date: simulation[:projected_payoff_date],
            total_interest_saved: simulation[:total_interest_paid]
          )
        end

        render json: { plan: plan, simulation: simulation }, status: :created
      end

      def index
        render json: current_user.debt_plans.order(created_at: :desc)
      end
    end
  end
end
