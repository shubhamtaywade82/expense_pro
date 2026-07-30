# frozen_string_literal: true

module Api
  module V1
    class InvestmentsController < BaseController
      before_action :set_investment, only: [ :update, :destroy ]

      def index
        investments = current_user.investments.recent_first

        if params[:asset_class].present? && params[:asset_class] != "all"
          investments = investments.where(asset_class: params[:asset_class])
        end

        if params[:status].present? && params[:status] != "all"
          investments = investments.where(status: params[:status])
        end

        if params[:financial_year].present?
          fy = params[:financial_year].to_i
          fy_start = Date.new(fy - 1, 4, 1)
          fy_end = Date.new(fy, 3, 31)
          investments = investments
            .where(purchase_date: fy_start..fy_end)
            .or(investments.where(status: "realized", sell_date: fy_start..fy_end))
        end

        total_invested = investments.sum(&:invested_amount)
        total_pnl = investments.sum(&:total_pnl)
        current_value = investments.sum(&:current_value)

        @pagy, paged_investments = pagy(investments)

        render json: {
          investments: paged_investments,
          summary: {
            total_invested: total_invested.to_s,
            current_value: current_value.to_s,
            total_pnl: total_pnl.to_s,
            count: investments.count
          },
          meta: {
            page: @pagy.page,
            per_page: @pagy.limit,
            total: @pagy.count,
            pages: @pagy.pages
          }
        }
      end

      def create
        investment = current_user.investments.build(investment_params)
        investment.save!
        render json: investment, status: :created
      end

      def update
        @investment.update!(investment_params)
        render json: @investment
      end

      def destroy
        @investment.destroy!
        head :no_content
      end

      private

      def set_investment
        @investment = current_user.investments.find(params[:id])
      end

      def investment_params
        params.permit(
          :name,
          :asset_class,
          :symbol,
          :quantity,
          :buy_price,
          :current_price,
          :sell_price,
          :purchase_date,
          :sell_date,
          :status,
          :notes
        )
      end
    end
  end
end
