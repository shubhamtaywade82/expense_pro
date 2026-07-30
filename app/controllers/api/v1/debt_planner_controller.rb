module Api
  module V1
    class DebtPlannerController < ApplicationController
      before_action :authenticate_request

      def summary
        service = DebtPlanningService.new(current_user)
        render json: service.debt_summary
      end

      def simulate
        strategy = params[:strategy] || "avalanche"
        extra_monthly = params[:extra_monthly].to_f

        service = DebtPlanningService.new(current_user)
        simulation = service.simulate_payoff(strategy: strategy, extra_monthly: extra_monthly)

        if simulation[:error]
          render json: { error: simulation[:error] }, status: :unprocessable_entity
        else
          render json: simulation
        end
      end
    end
  end
end
