module Api
  module V1
    class TaxController < BaseController
      def itr_summary
        year = (params[:financial_year] || Date.current.year).to_i
        
        # Try the new Python microservice first, fall back to Ruby service
        begin
          summary = ItrClientService.instance.calculate_tax(current_user, year)
          render json: summary
        rescue ItrClientService::ServiceUnavailableError => e
          Rails.logger.warn "ITR microservice unavailable, falling back to Ruby: #{e.message}"
          summary = TaxCalculatorService.new(current_user, year).call
          render json: summary
        end
      end

      def invalidate_cache
        year = params[:financial_year].to_i
        Rails.cache.delete("itr:#{current_user.id}:#{year}")
        head :no_content
      end
      
      def compare_regimes
        gross_income = params[:gross_income].to_f
        assessment_year = params[:assessment_year] || 'AY2026-27'
        
        begin
          result = ItrClientService.instance.compare_regimes(gross_income, assessment_year)
          render json: result
        rescue ItrClientService::ServiceUnavailableError => e
          render json: { error: e.message }, status: :service_unavailable
        end
      end
    end
  end
end
