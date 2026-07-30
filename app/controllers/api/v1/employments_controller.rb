module Api
  module V1
    class EmploymentsController < BaseController
      before_action :set_employment, only: [:update, :destroy, :fnf_settlement]

      def index
        render json: current_user.employments.by_recency.includes(:salary_components)
      end

      def create
        employment = current_user.employments.build(employment_params)
        if employment.save
          render json: employment, status: :created
        else
          render json: { errors: employment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @employment.update(employment_params)
          render json: @employment
        else
          render json: { errors: @employment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @employment.destroy!
        head :no_content
      end

      def fnf_settlement
        service = FnfSettlementService.new(@employment)
        result = service.call(settlement_params)
        if result[:errors]
          render json: result, status: :unprocessable_entity
        else
          render json: result
        end
      end

      private

      def set_employment
        @employment = current_user.employments.find(params[:id])
      end

      def employment_params
        params.permit(:employer_name, :designation, :start_date, :end_date, :is_current, :monthly_ctc, :pan_of_employer)
      end

      def settlement_params
        params.permit(:fnf_date, :gratuity_amount, :leave_encashment, :bonus_amount, :deductions)
      end
    end
  end
end
