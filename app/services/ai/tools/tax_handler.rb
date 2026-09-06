# frozen_string_literal: true

require "net/http"
require "uri"

module Ai
  module Tools
    class TaxHandler
      def initialize(user)
        @user = user
      end

      def calculate_tax_with_copilot(args)
        fy = args["financial_year"] || default_fy
        copilot_host = ENV.fetch("ITR_SERVICE_HOST", "http://localhost:8000")
        input_data = build_tax_input(args, fy)

        result = call_copilot_service(copilot_host, input_data)
        return result if result

        # Fallback to Ruby Tax Calculator
        tax = TaxCalculatorService.new(@user, fy).call rescue nil
        {
          success: true,
          engine: "ruby_fallback",
          tax_result: tax,
          fallback_used: true
        }
      end

      def explain_tax_provision(args)
        section = args["section"].to_s.upcase.strip
        detail = TAX_SECTIONS[section] || generic_tax_provision(section)

        {
          success: true,
          section: section,
          details: detail,
          disclaimer: "Informational summary under Indian Income Tax Act. Consult a Chartered Accountant for personalized filing advice."
        }
      end

      TAX_SECTIONS = {
        "80CCD(1B)" => {
          title: "Section 80CCD(1B) - Additional NPS Contribution",
          limit: "₹50,000 per financial year",
          applies_to: "Individuals (salaried or self-employed) contributing to NPS Tier-I",
          key_condition: "Over and above the ₹1,50,000 limit under Section 80C. Old Tax Regime only.",
          tax_savings: "Up to ₹15,600 (for 30% tax bracket + cess)"
        },
        "80C" => {
          title: "Section 80C - Specified Investments and Expenses",
          limit: "₹1,50,000 aggregate cap",
          applies_to: "Individuals and HUFs",
          eligible: "EPF, VPF, PPF, ELSS, Life Insurance Premiums, Home Loan Principal repayment, Sukanya Samriddhi",
          key_condition: "Applicable only under Old Tax Regime"
        },
        "80D" => {
          title: "Section 80D - Medical / Health Insurance Premiums",
          limit: "₹25,000 for self/family (₹50,000 if senior citizen) + ₹25,000 / ₹50,000 for parents",
          applies_to: "Individuals and HUFs",
          preventive_checkup: "Up to ₹5,000 within the overall limit"
        },
        "111A" => {
          title: "Section 111A - Short-Term Capital Gains (STCG) on Listed Equity",
          tax_rate: "20% (Budget 2024 amendment, effective July 23, 2024; was 15% previously)",
          applies_to: "Equity shares and equity mutual funds held for ≤ 12 months with STT paid"
        },
        "112A" => {
          title: "Section 112A - Long-Term Capital Gains (LTCG) on Listed Equity",
          tax_rate: "12.5% on gains exceeding ₹1,25,000 (Budget 2024 amendment, effective July 23, 2024)",
          applies_to: "Equity shares and equity mutual funds held for > 12 months with STT paid"
        },
        "24(B)" => {
          title: "Section 24(b) - Deductions on Home Loan Interest",
          limit: "Up to ₹2,00,000 for self-occupied property; actual interest for let-out property (capped at ₹2L set-off)",
          applies_to: "Home loan borrowers under Old Tax Regime"
        }
      }.freeze

      def generic_tax_provision(section)
        {
          title: "Indian Income Tax Provision: #{section}",
          notes: "Please refer to the Income Tax Department rules or ask for specific details regarding limits, eligibility, and Old vs New Regime applicability."
        }
      end

      def compare_tax_regimes(args)
        fy = args["financial_year"] || default_fy
        gross_income = args["gross_income"]&.to_f || 0.0

        if gross_income > 0
          ay = "AY#{fy}-#{(fy % 100) + 1}"
          begin
            result = ItrClientService.instance.compare_regimes(gross_income, ay)
            return { success: true, comparison: result }
          rescue StandardError => e
            Rails.logger.warn "[TaxHandler] ItrClientService error: #{e.message}"
          end
        end

        # Fallback using user's actual profile
        calc = TaxCalculatorService.new(@user, fy).call rescue nil
        {
          success: true,
          new_regime: calc&.dig(:new_regime),
          old_regime: calc&.dig(:old_regime),
          recommendation: calc&.dig(:recommendation)
        }
      end

      def itr_readiness_checklist(args)
        fy = args["financial_year"] || default_fy
        readiness = FilingReadinessService.new(@user, fy).call rescue {}
        checklist = DocumentChecklistService.new(@user, fy).status rescue {}

        {
          success: true,
          financial_year: fy,
          readiness: readiness,
          checklist: checklist
        }
      end

      private

      def default_fy
        today = Date.current
        today.month >= 4 && today.month <= 11 ? today.year : today.year + (today.month == 12 ? 1 : 0)
      end

      def build_tax_input(args, fy)
        {
          assessment_year: "AY#{fy}-#{(fy % 100) + 1}",
          gross_salary: (args["gross_salary"] || 0).to_f,
          freelance_income: (args["freelance_income"] || 0).to_f,
          interest_income: (args["interest_income"] || 0).to_f,
          dividend_income: (args["dividend_income"] || 0).to_f,
          speculative_pnl: (args["speculative_pnl"] || 0).to_f,
          non_speculative_fo_pnl: (args["non_speculative_fo_pnl"] || 0).to_f,
          stcg_111a: (args["stcg_111a"] || 0).to_f,
          ltcg_112a: (args["ltcg_112a"] || 0).to_f,
          crypto_pnl: (args["crypto_pnl"] || 0).to_f,
          deduction_80c: (args["deduction_80c"] || 0).to_f,
          deduction_80d: (args["deduction_80d"] || 0).to_f,
          deduction_80ccd_1b: (args["deduction_80ccd_1b"] || 0).to_f,
          deduction_80tta: (args["deduction_80tta"] || 0).to_f,
          hra_exemption: (args["hra_exemption"] || 0).to_f,
          home_loan_interest: (args["home_loan_interest"] || 0).to_f
        }
      end

      def call_copilot_service(host, input_data)
        uri = URI("#{host}/compare-regimes")
        req = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
        req.body = input_data.to_json
        res = Net::HTTP.start(uri.hostname, uri.port, read_timeout: 10) { |http| http.request(req) }
        return nil unless res.is_a?(Net::HTTPSuccess)

        data = JSON.parse(res.body)
        { success: true, engine: "india-itr-copilot", result: data }
      rescue StandardError => e
        Rails.logger.warn "[TaxHandler] Copilot HTTP error: #{e.message}"
        nil
      end
    end
  end
end
