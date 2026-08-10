module Api
  module V1
    class DebtPlansController < BaseController
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
            total_interest_saved: simulation[:interest_saved]
          )
        end

        render_camel_json({ plan: plan, simulation: simulation }, status: :created)
      end

      def index
        render json: current_user.debt_plans.order(created_at: :desc)
      end
    end
  end
end
