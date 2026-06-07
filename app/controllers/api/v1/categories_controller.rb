module Api
  module V1
    class CategoriesController < BaseController
      before_action :set_category, only: [ :update, :destroy ]
      before_action :ensure_not_default!, only: [ :update, :destroy ]

      def index
        render json: current_user.categories.order(:category_type, :name)
      end

      def create
        category = current_user.categories.build(category_params)
        category.save!
        render json: category, status: :created
      end

      def update
        @category.update!(category_params)
        render json: @category
      end

      def destroy
        @category.destroy!
        head :no_content
      rescue ActiveRecord::RecordNotDestroyed
        render json: { error: "Category is in use and cannot be deleted" }, status: :unprocessable_entity
      end

      private

      def set_category
        @category = current_user.categories.find(params[:id])
      end

      def ensure_not_default!
        render json: { error: "Default categories cannot be modified" }, status: :unprocessable_entity if @category.is_default?
      end

      def category_params
        permitted = params.permit(:name, :icon, :color, :type, :category_type)
        permitted[:category_type] ||= permitted[:type]
        permitted.except(:type)
      end
    end
  end
end
