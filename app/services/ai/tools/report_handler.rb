# frozen_string_literal: true

module Ai
  module Tools
    class ReportHandler
      def initialize(user)
        @user = user
      end

      def get_net_worth(_args)
        calc = NetWorthService.new(@user).calculate
        {
          success: true,
          net_worth: calc[:net_worth],
          total_assets: calc.dig(:assets, :total),
          total_liabilities: calc.dig(:liabilities, :total),
          liquid_cash: calc.dig(:assets, :liquid_cash),
          loans_count: calc.dig(:liabilities, :loans)&.size || 0,
          debt_to_asset_ratio: calc[:debt_to_asset_ratio],
          emergency_fund_months: calc[:emergency_fund_months]
        }
      end

      def get_financial_summary(args)
        month = args["month"] || Date.current.month
        year  = args["year"]  || Date.current.year
        fy    = args["financial_year"] || default_fy

        dashboard = DashboardService.new(@user, month: month, year: year).overview
        tax = TaxCalculatorService.new(@user, fy).call rescue nil

        {
          success: true,
          summary: {
            month: month,
            year: year,
            income: { total: dashboard.dig(:income, :total), received: dashboard.dig(:income, :received) },
            expenses: { total: dashboard.dig(:expenses, :total), count: dashboard.dig(:expenses, :count) },
            bills: { total: dashboard.dig(:bills, :total), paid: dashboard.dig(:bills, :paid), unpaid: dashboard.dig(:bills, :unpaid) },
            emis: { total: dashboard.dig(:emis, :total), paid_count: dashboard.dig(:emis, :paid) },
            overall: dashboard[:overall],
            tax: tax ? {
              fy: tax[:financial_year],
              total_tax_new: tax.dig(:new_regime, :total_tax),
              total_tax_old: tax.dig(:old_regime, :total_tax),
              recommended_regime: tax.dig(:recommendation, :best_regime)
            } : nil
          }
        }
      end

      def get_monthly_report(args)
        month = (args["month"] || Date.current.month).to_i
        year  = (args["year"] || Date.current.year).to_i
        report = ReportService.new(@user).monthly(month: month, year: year)

        {
          success: true,
          month: month,
          year: year,
          report: report
        }
      end

      private

      def default_fy
        today = Date.current
        today.month >= 4 && today.month <= 11 ? today.year : today.year + (today.month == 12 ? 1 : 0)
      end
    end
  end
end
