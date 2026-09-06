# frozen_string_literal: true

module Ai
  class ToolExecutor
    attr_reader :user, :core_handler, :debt_handler, :broker_handler, :tax_handler, :report_handler

    def initialize(user)
      @user = user
      @core_handler = Tools::CoreHandler.new(user)
      @debt_handler = Tools::DebtHandler.new(user)
      @broker_handler = Tools::BrokerHandler.new(user)
      @tax_handler = Tools::TaxHandler.new(user)
      @report_handler = Tools::ReportHandler.new(user)
    end

    def execute(tool_call_or_name, args = nil)
      name = tool_call_or_name.respond_to?(:name) ? tool_call_or_name.name : tool_call_or_name.to_s
      arguments = extract_arguments(tool_call_or_name, args)
      dispatch(name, arguments)
    rescue StandardError => e
      Rails.logger.error "[Ai::ToolExecutor] Error executing #{name}: #{e.message}"
      { success: false, message: "Error: #{e.message}" }
    end

    private

    def extract_arguments(tool_call_or_name, args)
      raw = if args
              args
      elsif tool_call_or_name.respond_to?(:arguments)
              tool_call_or_name.arguments
      else
              {}
      end
      raw = JSON.parse(raw) if raw.is_a?(String)
      raw.respond_to?(:stringify_keys) ? raw.stringify_keys : {}
    end

    def dispatch(name, args)
      case name
      when "create_category", "list_categories", "delete_category",
           "create_expense", "list_expenses", "update_expense", "delete_expense",
           "create_income", "list_incomes", "update_income", "delete_income", "toggle_income_received",
           "create_bill", "list_bills", "pay_bill", "delete_bill",
           "create_loan", "list_loans", "pay_emi", "delete_loan",
           "create_budget", "list_budgets", "delete_budget",
           "create_investment", "list_investments", "update_investment", "delete_investment"
        dispatch_core(name, args)
      when "list_credit_cards", "list_debt_accounts", "get_legal_status", "generate_ots_letter",
           "debt_overview", "settlement_queue", "settle_with_amount", "debt_forecast",
           "compare_settlement_scenarios", "add_settlement_contribution"
        dispatch_debt(name, args)
      when "get_broker_snapshots", "get_dhan_pnl_summary", "sync_broker_data"
        dispatch_broker(name, args)
      when "calculate_tax_with_copilot", "explain_tax_provision", "compare_tax_regimes", "itr_readiness_checklist"
        dispatch_tax(name, args)
      when "get_net_worth", "get_financial_summary", "get_monthly_report"
        dispatch_report(name, args)
      else
        { success: false, message: "Unknown tool: #{name}" }
      end
    end

    def dispatch_core(name, args)
      @core_handler.public_send(name, args)
    end

    def dispatch_debt(name, args)
      %w[debt_overview settlement_queue].include?(name) ? @debt_handler.public_send(name) : @debt_handler.public_send(name, args)
    end

    def dispatch_broker(name, args)
      @broker_handler.public_send(name, args)
    end

    def dispatch_tax(name, args)
      @tax_handler.public_send(name, args)
    end

    def dispatch_report(name, args)
      @report_handler.public_send(name, args)
    end
  end
end
