module Api
  module V1
    class TaxController < BaseController
      def itr_summary
        year = (params[:financial_year] || Date.current.year).to_i
        summary = TaxCalculatorService.new(current_user, year).call
        render json: summary
      end

      def invalidate_cache
        year = params[:financial_year].to_i
        Rails.cache.delete("itr:#{current_user.id}:#{year}")
        head :no_content
      end
    end
  end
end
