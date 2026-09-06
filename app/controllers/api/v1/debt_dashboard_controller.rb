require "csv"

module Api
  module V1
    # The Debt Clearance Dashboard:
    #   GET overview  — totals, fund, pipeline, cashflow, debt-free date
    #   GET forecast  — projected settlement dates for an allocation
    #   GET simulate_settlement — "what can I settle with ₹X?"
    #   GET export_csv — export database/loans/cards/summary in CSV format
    class DebtDashboardController < BaseController
      def overview
        render_camel_json DebtClearanceService.new(current_user).overview
      end

      def forecast
        engine = DebtForecastEngine.new(current_user, monthly_allocation: params[:monthly_allocation])
        render_camel_json forecast_payload(engine.call)
      end

      def simulate_settlement
        if params[:amount].blank?
          return render_camel_json({ error: "amount is required" }, status: :bad_request)
        end

        render_camel_json SettlementSimulator.new(current_user).call(available_cash: params[:amount])
      end

      def export_csv
        sheet_type = params[:sheet_type].to_s
        csv_data, filename = generate_csv(sheet_type)
        send_data csv_data, filename: filename, type: "text/csv; charset=utf-8"
      end

      private

      def generate_csv(sheet_type)
        case sheet_type
        when "loans" then [generate_loans_csv, "loans.csv"]
        when "cards" then [generate_cards_csv, "credit_cards.csv"]
        when "summary" then [generate_summary_csv, "summary.csv"]
        else [generate_database_csv, "Debt_Database.csv"]
        end
      end

      def generate_database_csv
        CSV.generate(headers: true) do |csv|
          csv << ["Type", "Category", "Lender / Product", "Account Last 4", "Sanctioned / Limit (INR)", "Current Balance (INR)", "Overdue Amount (INR)", "Monthly Obligation (INR)", "ROI (%)", "Tenure", "Months Remaining", "Status", "Notes"]
          current_user.debt_accounts.order(:classification, current_balance_paise: :desc).each do |a|
            csv << [
              a.debt_type.titleize,
              a.serviced? ? "Secured" : "Unsecured - #{a.bureau_status || a.status.titleize}",
              a.name, a.name[/\((\w+)\)/, 1] || "—",
              "%.2f" % a.original_principal.to_f, "%.2f" % a.current_balance.to_f,
              "%.2f" % a.overdue_amount.to_f, "%.2f" % a.monthly_cashflow_demand.to_f,
              a.interest_rate ? "#{a.interest_rate}%" : "N/A",
              a.tenure_months ? "#{a.tenure_months} mos" : "—",
              a.remaining_tenure_months ? "#{a.remaining_tenure_months} mos" : "—",
              a.bureau_status || a.status.titleize, a.notes
            ]
          end
        end
      end

      def generate_loans_csv
        CSV.generate(headers: true) do |csv|
          csv << ["Loan Type", "Lender", "Principal Amount (INR)", "Outstanding Balance (INR)", "EMI (INR)", "ROI (%)", "Start Date", "Due Day", "Paid Amount (INR)", "Remaining Due (INR)", "Full Due Date", "Status", "Tenure", "Months Remaining", "Overdue Amount (INR)", "Remarks"]
          current_user.debt_accounts.where.not(debt_type: :credit_card).order(:classification, current_balance_paise: :desc).each do |a|
            csv << [
              a.debt_type.titleize, a.lender,
              "%.2f" % a.original_principal.to_f, "%.2f" % a.current_balance.to_f,
              "%.2f" % a.monthly_cashflow_demand.to_f,
              a.interest_rate ? "#{a.interest_rate}%" : "N/A",
              a.created_at.strftime("%-m/%-d/%Y"), a.due_day || "—", "0.00",
              "%.2f" % a.monthly_cashflow_demand.to_f,
              a.due_day ? "10/#{a.due_day}/2026" : "—",
              a.bureau_status || a.status.titleize,
              a.tenure_months ? "#{a.tenure_months} mos" : "—",
              a.remaining_tenure_months ? "#{a.remaining_tenure_months} mos" : "—",
              "%.2f" % a.overdue_amount.to_f, a.notes
            ]
          end
        end
      end

      def generate_cards_csv
        CSV.generate(headers: true) do |csv|
          csv << ["Card Name", "Account Last 4", "Statement Day", "Due Day", "Outstanding Balance (INR)", "Overdue Amount (INR)", "Limit (INR)", "Utilisation (%)", "Remaining Due (INR)", "Status", "Remarks"]
          current_user.debt_accounts.credit_card.order(current_balance_paise: :desc).each do |a|
            csv << [
              a.name, a.name[/\((\w+)\)/, 1] || "—",
              a.statement_day || "—", a.due_day || "—",
              "%.2f" % a.current_balance.to_f, "%.2f" % a.overdue_amount.to_f,
              "%.2f" % a.credit_limit.to_f, "%.2f%%" % a.utilization_percentage,
              "%.2f" % (a.overdue_amount.positive? ? a.overdue_amount.to_f : a.current_balance.to_f),
              a.bureau_status || a.status.titleize, a.notes
            ]
          end
        end
      end

      def generate_summary_csv
        capital = SettlementCapitalService.new(current_user).call
        accounts = current_user.debt_accounts
        CSV.generate(headers: true) do |csv|
          csv << ["Category", "Details", "Amount (INR)", "Notes"]
          csv << ["Total Monthly Income", "Net Take-home Salary", "%.2f" % capital[:monthly_income], "Verified monthly cash inflow"]
          csv << ["Fixed Living Expenses", "Housing + Food + Transport + Bills", "-30000.00", "Baseline living expenses"]
          csv << ["Active Secured EMIs", "Tata Capital Housing + Property", "-%.2f" % (accounts.serviced.open.sum(:monthly_obligation_paise) / 100.0), "Non-negotiable secured protection"]
          csv << ["Net Monthly Free Cash Flow", "Monthly Settlement Reserve", "+%.2f" % capital[:settlement_allocation], "Dedicated snowball surplus for OTS"]
          csv << ["Secured Debt Total", "Tata Capital Housing + Property", "%.2f" % (accounts.serviced.open.sum(:current_balance_paise) / 100.0), "Zero overdue; standard servicing"]
          csv << ["Unsecured Debt Total", "Credit Cards + Fintech + Personal Loans", "%.2f" % (accounts.settlement.open.sum(:current_balance_paise) / 100.0), "In recovery / write-off / delinquency"]
          csv << ["Total Bureau Debt", "CRIF Verified Primary Current Balance", "%.2f" % (accounts.open.sum(:current_balance_paise) / 100.0), "True total liability"]
          csv << ["Total Overdue / Default", "CRIF Verified Total Overdue Amount", "%.2f" % (accounts.sum(:overdue_amount_paise) / 100.0), "Legal & recovery risk exposure"]
          csv << ["Credit Bureau Score", "CRIF High Mark Score (Sept 2026)", "510", "Immediate focus is resolving legal/recovery threats"]
        end
      end

      def forecast_payload(result)
        {
          monthly_allocation: result.monthly_allocation,
          start_fund: result.start_fund,
          months_used: result.months_used,
          debt_free_on: result.debt_free_on,
          total_settlement_cost: result.total_settlement_cost,
          settlements: result.settlements
        }
      end
    end
  end
end
