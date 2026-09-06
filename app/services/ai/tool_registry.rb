# frozen_string_literal: true

require "ruby_llm"

module Ai
  class ToolRegistry
    class GenericTool < RubyLLM::Tool
      def initialize(name, description, schema, executor)
        @tool_name = name.to_s
        @tool_desc = description
        @tool_schema = schema
        @executor = executor
        super()
      end

      def name; @tool_name; end
      def description; @tool_desc; end
      def params_schema; @tool_schema; end

      def execute(**kwargs)
        @executor.execute(@tool_name, kwargs.transform_keys(&:to_s))
      end
    end

    def self.ruby_llm_tools(executor)
      definitions.map do |defn|
        GenericTool.new(defn[:name], defn[:description], defn[:parameters], executor)
      end
    end

    def self.ruby_llm_tools_for(query, executor, provider = nil)
      defns = relevant_definitions_for(query, provider)
      defns.map do |defn|
        GenericTool.new(defn[:name], defn[:description], defn[:parameters], executor)
      end
    end

    def self.relevant_definitions_for(query, provider)
      return definitions if %i[gemini anthropic openai deepseek].include?(provider)

      q = query.to_s.downcase
      matched = report_definitions.dup

      matched += debt_definitions if q.match?(/\b(card|cards|credit|debt|settle|settlement|loan|loans|emi|overdue|legal|ots|letter|bureau|cibil|crif|stashfin|akara|hdfc|sbi|axis|rbl|icici)\b/)
      matched += broker_definitions if q.match?(/\b(dhan|broker|trade|trading|stock|stocks|holding|holdings|position|positions|pnl|margin|portfolio)\b/)
      matched += tax_definitions if q.match?(/\b(tax|itr|80c|80d|regime|deduction|exemption|copilot|filing|form 16)\b/)
      matched += core_definitions if q.match?(/\b(expense|expenses|spend|spent|income|salary|earn|earned|bill|bills|budget|budgets|category|categories|invest|investment)\b/) || matched.size <= 3

      matched.uniq { |d| d[:name] }
    end

    def self.t(name, desc, props = {}, req = [])
      params = { "type" => "object", "properties" => props.stringify_keys }
      params["required"] = req if req.any?
      { name: name.to_s, description: desc, parameters: params }
    end

    def self.definitions
      @definitions ||= (
        core_definitions + debt_definitions + broker_definitions + tax_definitions + report_definitions
      ).freeze
    end

    def self.core_definitions
      [
        t(:create_category, "Create a new category for expenses, income, bills, or loans.", {
          name: { type: "string" }, category_type: { type: "string", enum: %w[expense income bill loan emi] },
          icon: { type: "string" }, color: { type: "string" }
        }, %w[name category_type]),
        t(:list_categories, "List user categories, optionally filtered by type.", {
          category_type: { type: "string", enum: %w[expense income bill loan emi] }
        }),
        t(:delete_category, "Delete a category by ID.", { id: { type: "integer" } }, %w[id]),
        t(:create_expense, "Log a new expense.", {
          amount: { type: "number" }, category_name: { type: "string" },
          payment_method: { type: "string", enum: %w[cash credit_card debit_card upi net_banking other] },
          expense_date: { type: "string" }, description: { type: "string" }
        }, %w[amount category_name payment_method description]),
        t(:list_expenses, "List expenses for month and year, or search by term.", {
          month: { type: "integer" }, year: { type: "integer" }, search: { type: "string" },
          category_name: { type: "string" }, limit: { type: "integer" }
        }),
        t(:update_expense, "Update an existing expense.", {
          id: { type: "integer" }, amount: { type: "number" }, description: { type: "string" },
          category_name: { type: "string" }, payment_method: { type: "string" }, expense_date: { type: "string" }
        }, %w[id]),
        t(:delete_expense, "Delete an expense by ID.", { id: { type: "integer" } }, %w[id]),
        t(:create_income, "Record income from salary, freelance, etc.", {
          source: { type: "string" }, amount: { type: "number" }, income_date: { type: "string" },
          frequency: { type: "string", enum: %w[weekly monthly quarterly yearly one_time] },
          is_recurring: { type: "boolean" }, notes: { type: "string" }
        }, %w[source amount]),
        t(:list_incomes, "List incomes for month/year.", { month: { type: "integer" }, year: { type: "integer" } }),
        t(:update_income, "Update income record.", { id: { type: "integer" }, source: { type: "string" }, amount: { type: "number" }, notes: { type: "string" } }, %w[id]),
        t(:delete_income, "Delete income record.", { id: { type: "integer" } }, %w[id]),
        t(:toggle_income_received, "Toggle income received status.", { id: { type: "integer" } }, %w[id]),
        t(:create_bill, "Create monthly bill template.", {
          name: { type: "string" }, amount: { type: "number" }, category_name: { type: "string" },
          due_date: { type: "integer" }, reminder_days: { type: "integer" }, notes: { type: "string" }
        }, %w[name amount category_name due_date]),
        t(:list_bills, "List active monthly bills.", { show_paid: { type: "boolean" } }),
        t(:pay_bill, "Mark bill as paid.", { bill_id: { type: "integer" } }, %w[bill_id]),
        t(:delete_bill, "Delete bill by ID.", { id: { type: "integer" } }, %w[id]),
        t(:create_loan, "Record loan with EMI schedule.", {
          name: { type: "string" }, category_name: { type: "string" }, principal_amount: { type: "number" },
          interest_rate: { type: "number" }, tenure_months: { type: "integer" }, start_date: { type: "string" },
          lender: { type: "string" }, loan_type: { type: "string", enum: %w[home car personal education business gold other] }
        }, %w[name category_name principal_amount interest_rate tenure_months start_date]),
        t(:list_loans, "List all active loans with balances.", {}),
        t(:pay_emi, "Mark loan EMI paid.", { loan_id: { type: "integer" }, emi_number: { type: "integer" }, paid_date: { type: "string" } }, %w[loan_id emi_number]),
        t(:delete_loan, "Delete loan by ID.", { id: { type: "integer" } }, %w[id]),
        t(:create_budget, "Set monthly budget for category.", {
          category_name: { type: "string" }, amount: { type: "number" }, month: { type: "integer" }, year: { type: "integer" }, alert_threshold: { type: "integer" }
        }, %w[category_name amount]),
        t(:list_budgets, "List budgets with spending progress.", { month: { type: "integer" }, year: { type: "integer" } }),
        t(:delete_budget, "Delete budget by ID.", { id: { type: "integer" } }, %w[id]),
        t(:create_investment, "Record investment asset.", {
          name: { type: "string" }, asset_class: { type: "string" }, symbol: { type: "string" },
          quantity: { type: "number" }, buy_price: { type: "number" }, purchase_date: { type: "string" },
          current_price: { type: "number" }, notes: { type: "string" }
        }, %w[name asset_class quantity buy_price purchase_date]),
        t(:list_investments, "List investments with P&L.", { asset_class: { type: "string" }, status: { type: "string", enum: %w[active realized] } }),
        t(:update_investment, "Update investment details or sell price.", {
          id: { type: "integer" }, sell_price: { type: "number" }, sell_date: { type: "string" }, current_price: { type: "number" }, status: { type: "string" }, notes: { type: "string" }
        }, %w[id]),
        t(:delete_investment, "Delete investment by ID.", { id: { type: "integer" } }, %w[id])
      ]
    end

    def self.debt_definitions
      [
        t(:list_credit_cards, "List all credit cards with limits, balances, overdue amounts, utilization %, and due dates.", {}),
        t(:list_debt_accounts, "List all 29 debt accounts with filters (account_type, category: serviced/settlement_pool, overdue_only).", {
          account_type: { type: "string" }, category: { type: "string" }, overdue_only: { type: "boolean" }
        }),
        t(:get_legal_status, "Get active legal alerts, court suits (e.g. Akara/Stashfin), and high-risk debt accounts.", {}),
        t(:generate_ots_letter, "Generate an RBI-compliant formal One-Time Settlement (OTS) letter for a lender.", {
          lender: { type: "string" }, debt_account_id: { type: "integer" }, proposed_percentage: { type: "number" }
        }),
        t(:debt_overview, "Get total/serviced/settlement debt breakdown, settlement fund, and debt-free date.", {}),
        t(:settlement_queue, "Ranked settlement queue: target account, stage, priority score, and funding progress.", {}),
        t(:settle_with_amount, "Simulate settlements possible with a given cash amount.", { amount: { type: "number" } }, %w[amount]),
        t(:debt_forecast, "Project debt-free date given monthly settlement allocation.", { monthly_allocation: { type: "number" } }),
        t(:compare_settlement_scenarios, "Compare settlement costs at 20/25/30/35/40/45 percent for an account.", {
          settlement_case_id: { type: "integer" }, account_name: { type: "string" }
        }),
        t(:add_settlement_contribution, "Record money saved towards a settlement case.", {
          settlement_case_id: { type: "integer" }, account_name: { type: "string" }, amount: { type: "number" },
          contributed_on: { type: "string" }, source: { type: "string" }, notes: { type: "string" }
        }, %w[amount])
      ]
    end

    def self.broker_definitions
      [
        t(:get_broker_snapshots, "Get Dhan/broker portfolio snapshot: holdings, positions, margin, and last sync.", {}),
        t(:get_dhan_pnl_summary, "Get Dhan trading PnL summary across equity, F&O, and commodities.", {}),
        t(:sync_broker_data, "Trigger background sync of Dhan holdings and positions into ExpensePro.", {})
      ]
    end

    def self.tax_definitions
      [
        t(:calculate_tax_with_copilot, "Calculate Indian income tax using india-itr-copilot engine with deductions, F&O losses, marginal relief.", {
          financial_year: { type: "integer" }, gross_salary: { type: "number" }, freelance_income: { type: "number" },
          interest_income: { type: "number" }, dividend_income: { type: "number" }, speculative_pnl: { type: "number" },
          non_speculative_fo_pnl: { type: "number" }, stcg_111a: { type: "number" }, ltcg_112a: { type: "number" },
          crypto_pnl: { type: "number" }, deduction_80c: { type: "number" }, deduction_80d: { type: "number" },
          deduction_80ccd_1b: { type: "number" }, deduction_80tta: { type: "number" }, hra_exemption: { type: "number" },
          home_loan_interest: { type: "number" }
        }, %w[financial_year]),
        t(:explain_tax_provision, "Explain Indian tax provisions, sections (e.g. 80C, 111A, marginal relief), and limits.", {
          section: { type: "string" }, context: { type: "string" }
        }, %w[section]),
        t(:compare_tax_regimes, "Compare Old Regime vs New Regime tax calculation for user or given income.", {
          financial_year: { type: "integer" }, gross_income: { type: "number" }
        }),
        t(:itr_readiness_checklist, "Check readiness and missing documents (Form 16, AIS/TIS, P&L) for filing ITR.", {
          financial_year: { type: "integer" }
        })
      ]
    end

    def self.report_definitions
      [
        t(:get_net_worth, "Get real-time Net Worth calculation: total assets, total liabilities, liquid cash, and debt ratio.", {}),
        t(:get_financial_summary, "Get monthly/yearly financial summary: income, expenses, bills, EMIs, tax, savings.", {
          month: { type: "integer" }, year: { type: "integer" }, financial_year: { type: "integer" }
        }),
        t(:get_monthly_report, "Get comprehensive monthly expense report with category breakdown vs budget.", {
          month: { type: "integer" }, year: { type: "integer" }
        })
      ]
    end
  end
end
