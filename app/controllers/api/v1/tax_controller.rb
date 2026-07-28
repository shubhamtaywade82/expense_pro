# frozen_string_literal: true

module Api
  module V1
    class TaxController < BaseController
      def itr_summary
        year = (params[:financial_year] || Date.current.year).to_i
        summary = TaxCalculatorService.new(current_user, year).call
        render json: summary
      end
    end
  end
end
