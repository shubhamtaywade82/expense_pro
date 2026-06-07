module Api
  module V1
    class DashboardController < BaseController
      def overview
        now = Date.current
        month = params[:month].presence || now.month
        year = params[:year].presence || now.year

        render json: DashboardService.new(current_user, month: month, year: year).overview
      end
    end
  end
end
