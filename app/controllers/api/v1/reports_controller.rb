module Api
  module V1
    class ReportsController < BaseController
      def monthly
        now = Date.current
        month = params[:month].presence || now.month
        year = params[:year].presence || now.year

        render json: ReportService.new(current_user).monthly(month: month.to_i, year: year.to_i)
      end

      def financial_year
        year = params[:year].presence || fiscal_year_for(Date.current)

        render json: ReportService.new(current_user).financial_year(year: year.to_i)
      end

      private

      def fiscal_year_for(date)
        date.month >= 4 ? date.year : date.year - 1
      end
    end
  end
end
