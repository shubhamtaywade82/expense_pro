module Api
  module V1
    class TaxDeductionsController < BaseController
      before_action :set_income
      before_action :set_deduction, only: [:update, :destroy]

      def index
        render json: @income.tax_deductions
      end

      def create
        deduction = @income.tax_deductions.build(deduction_params)
        if deduction.save
          render json: deduction, status: :created
        else
          render json: { errors: deduction.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @deduction.update(deduction_params)
          render json: @deduction
        else
          render json: { errors: @deduction.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @deduction.destroy!
        head :no_content
      end

      private

      def set_income
        @income = current_user.incomes.find(params[:income_id])
      end

      def set_deduction
        @deduction = @income.tax_deductions.find(params[:id])
      end

      def deduction_params
        params.permit(:deduction_type, :tds_amount, :paid_on, :remarks)
      end
    end
  end
end
