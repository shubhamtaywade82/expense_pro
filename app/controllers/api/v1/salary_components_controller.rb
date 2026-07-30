module Api
  module V1
    class SalaryComponentsController < BaseController
      before_action :set_employment
      before_action :set_component, only: [:update, :destroy]

      def index
        render json: @employment.salary_components
      end

      def create
        component = @employment.salary_components.build(component_params)
        if component.save
          render json: component, status: :created
        else
          render json: { errors: component.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @component.update(component_params)
          render json: @component
        else
          render json: { errors: @component.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @component.destroy!
        head :no_content
      end

      private

      def set_employment
        @employment = current_user.employments.find(params[:employment_id])
      end

      def set_component
        @component = @employment.salary_components.find(params[:id])
      end

      def component_params
        params.permit(:component_type, :component_label, :monthly_amount, :is_taxable, :is_exempt_under_80c, :hra_rent_paid)
      end
    end
  end
end
