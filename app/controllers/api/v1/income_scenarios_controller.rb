module Api
  module V1
    # Salary/income scenarios ("what changes after appraisal?") that feed
    # the capital calculation and the clearance forecast.
    class IncomeScenariosController < BaseController
      before_action :set_scenario, only: %i[update destroy activate]

      def index
        render_camel_json current_user.income_scenarios.order(:effective_on).map { |s| payload(s) }
      end

      def create
        scenario = current_user.income_scenarios.create!(scenario_params)
        scenario.activate! if ActiveModel::Type::Boolean.new.cast(params[:is_active])
        render_camel_json payload(scenario), status: :created
      end

      def update
        @scenario.update!(scenario_params)
        render_camel_json payload(@scenario)
      end

      def destroy
        @scenario.destroy!
        head :no_content
      end

      # PATCH /api/v1/income_scenarios/:id/activate
      def activate
        @scenario.activate!
        render_camel_json payload(@scenario)
      end

      private

      def set_scenario
        @scenario = current_user.income_scenarios.find(params[:id])
      end

      def scenario_params
        permitted = params.permit(:name, :scenario_type, :effective_on, :monthly_income,
                                  :monthly_commitments, :settlement_allocation, :buffer_allocation,
                                  :is_active, :notes)

        %i[monthly_income monthly_commitments settlement_allocation buffer_allocation].each do |money_field|
          permitted["#{money_field}_paise"] = (permitted.delete(money_field).to_f * 100).round if permitted.key?(money_field)
        end
        permitted[:effective_on] = Date.parse(permitted[:effective_on]) if permitted[:effective_on].present?
        permitted
      rescue Date::Error
        raise ActionController::BadRequest, "effective_on must be YYYY-MM-DD"
      end

      def payload(scenario)
        scenario.as_json.merge(
          "monthlyIncome" => scenario.monthly_income.to_f,
          "monthlyCommitments" => scenario.monthly_commitments.to_f,
          "settlementAllocation" => scenario.settlement_allocation.to_f,
          "bufferAllocation" => scenario.buffer_allocation.to_f,
          "monthlySurplus" => scenario.monthly_surplus.to_f
        )
      end
    end
  end
end
