module Api
  module V1
    class ItrFilingController < ApplicationController
      before_action :authenticate_request

      def prefill
        fy = params[:financial_year]&.to_i || TaxCalculatorService.default_financial_year
        # Mock payload for now until ItrPrefillService is fully implemented
        payload = {
          formName: params[:form] || "ITR-1",
          assessmentYear: (fy + 1).to_s,
          status: "O",
          itrForm: {
            personalInfo: {
              pan: current_user.pan,
              name: current_user.full_name
            }
          }
        }

        render json: payload
      end

      def download
        fy = params[:financial_year]&.to_i || TaxCalculatorService.default_financial_year
        payload = {
          formName: "ITR-1",
          assessmentYear: (fy + 1).to_s,
          status: "O"
        }

        send_data payload.to_json,
                  filename: "ITR_#{payload[:formName]}_AY#{payload[:assessmentYear]}_#{current_user.pan}.json",
                  type: :json
      end

      def readiness
        fy = params[:financial_year]&.to_i || TaxCalculatorService.default_financial_year
        
        # Mock readiness data for now until FilingReadinessService is fully implemented
        render json: {
          financial_year: fy,
          can_file_self: true,
          ca_required: false,
          ca_required_reasons: [],
          blockers: [],
          blocker_count: 0,
          reconciliation_status: :ok,
          recommended_form: "ITR-1",
          due_date: "#{fy + 1}-07-31",
          estimated_tax: 0,
          next_steps: [
            "Download pre-filled JSON",
            "Submit on incometax.gov.in → e-File → Upload JSON",
            "E-verify within 30 days via Aadhaar OTP (fastest) or EVC"
          ]
        }
      end

      def checklist
        fy = params[:financial_year]&.to_i || TaxCalculatorService.default_financial_year
        
        # Mock checklist data
        render json: {
          financial_year: fy,
          persona: [:individual],
          total_required: 2,
          total_uploaded: 0,
          total_verified: 0,
          completion_pct: 0,
          missing_required: ["pan_card", "form_26as"],
          pending_verification: [],
          checklist: [
            {
              document_type: "pan_card",
              label: "PAN Card",
              status: :missing,
              mandatory: true,
              tip: nil
            },
            {
              document_type: "form_26as",
              label: "Form 26AS",
              status: :missing,
              mandatory: true,
              tip: "Download from TRACES. Password-protected — we decrypt it automatically using your PAN + DOB."
            }
          ]
        }
      end
    end
  end
end
