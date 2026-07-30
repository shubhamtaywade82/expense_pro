module Api
  module V1
    class ItrFilingController < ApplicationController
      before_action :authenticate_request

      # GET /api/v1/itr_filing/prefill?financial_year=2025&form=ITR-2
      def prefill
        fy = params[:financial_year]&.to_i || TaxCalculatorService.default_financial_year
        payload = ItrPrefillService.new(current_user, fy).generate(itr_form: params[:form])

        render json: payload
      end

      # GET /api/v1/itr_filing/download.json — the filing artifact
      def download
        fy = params[:financial_year]&.to_i || TaxCalculatorService.default_financial_year
        payload = ItrPrefillService.new(current_user, fy).generate

        send_data payload.to_json,
                  filename: "ITR_#{payload[:formName]}_AY#{payload[:assessmentYear]}_#{current_user.pan}.json",
                  type: :json
      end

      # GET /api/v1/itr_filing/readiness — can this user file without a CA?
      def readiness
        fy = params[:financial_year]&.to_i || TaxCalculatorService.default_financial_year
        render json: FilingReadinessService.new(current_user, fy).call
      end

      # GET /api/v1/itr_filing/checklist — what's still missing?
      def checklist
        fy = params[:financial_year]&.to_i || TaxCalculatorService.default_financial_year
        render json: DocumentChecklistService.new(current_user, fy).status
      end
    end
  end
end
