module Api
  module V1
    # The Debt Clearance Dashboard:
    #   GET overview  — totals, fund, pipeline, cashflow, debt-free date
    #   GET forecast  — projected settlement dates for an allocation
    #   GET simulate_settlement — "what can I settle with ₹X?"
    class DebtDashboardController < BaseController
      def overview
        render_camel_json DebtClearanceService.new(current_user).overview
      end

      def forecast
        engine = DebtForecastEngine.new(current_user, monthly_allocation: params[:monthly_allocation])
        render_camel_json forecast_payload(engine.call)
      end

      def simulate_settlement
        if params[:amount].blank?
          return render_camel_json({ error: "amount is required" }, status: :bad_request)
        end

        render_camel_json SettlementSimulator.new(current_user).call(available_cash: params[:amount])
      end

      private

      def forecast_payload(result)
        {
          monthly_allocation: result.monthly_allocation,
          start_fund: result.start_fund,
          months_used: result.months_used,
          debt_free_on: result.debt_free_on,
          total_settlement_cost: result.total_settlement_cost,
          settlements: result.settlements
        }
      end
    end
  end
end
