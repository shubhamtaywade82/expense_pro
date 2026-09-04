module Api
  module V1
    # Money the user sets aside towards a case's settlement fund.
    class SettlementContributionsController < BaseController
      before_action :set_case

      def create
        contribution = @case.settlement_contributions.create!(contribution_params)

        # Funding the case nudges the state machine forward: drafting ->
        # funding once real money starts piling up.
        @case.update!(status: :funding) if @case.drafting?

        render_camel_json contribution.as_json.merge("amount" => contribution.amount.to_f), status: :created
      end

      def destroy
        @case.settlement_contributions.find(params[:id]).destroy!
        head :no_content
      end

      private

      def set_case
        @case = current_user.settlement_cases.find(params[:settlement_case_id])
      end

      def contribution_params
        permitted = params.permit(:contributed_on, :amount, :source, :reference, :notes)
        permitted[:amount_paise] = (permitted.delete(:amount).to_f * 100).round if permitted.key?(:amount)
        permitted[:contributed_on] = parse_date(permitted[:contributed_on]) || Date.current if permitted.key?(:contributed_on)
        permitted[:user] = current_user
        permitted
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue Date::Error
        nil
      end
    end
  end
end
