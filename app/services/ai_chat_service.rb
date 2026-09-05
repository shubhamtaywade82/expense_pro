# frozen_string_literal: true

class AiChatService
  def initialize(user)
    @user = user
    config = Ollama::Config.new
    config.base_url = ENV.fetch("OLLAMA_HOST", "http://localhost:11434")
    config.api_key = ENV["OLLAMA_API_KEY"]
    config.model = ENV.fetch("OLLAMA_MODEL", "qwen3.5:4b")
    config.temperature = 0.2
    config.timeout = 60
    @client = Ollama::Client.new(config: config)
    @tool_executor = Ai::ToolExecutor.new(user)
  end

  def chat(message, history = [])
    messages = [
      { role: "system", content: build_system_prompt },
      *sanitize_history(history),
      { role: "user", content: message }
    ]

    response = @client.chat(messages: messages, tools: available_tools)
    response = handle_tool_calls(response, messages) if response.message.tool_calls&.any?

    { role: "assistant", content: response.message.content }
  rescue StandardError => e
    Rails.logger.error "[AiChatService] Error: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    { role: "assistant", content: "Sorry, I encountered an error: #{e.message}" }
  end

  private

  def build_system_prompt
    Ai::PromptBuilder.new(@user).build
  end

  def handle_tool_calls(response, messages)
    tool_calls = response.message.tool_calls
    messages << {
      role: "assistant",
      content: response.message.content || "",
      tool_calls: tool_calls.map { |tc| { id: tc.id, type: "function", function: { name: tc.name, arguments: tc.arguments } } }
    }

    tool_calls.each do |tc|
      result = @tool_executor.execute(tc)
      messages << { role: "tool", tool_call_id: tc.id, name: tc.name, content: result.to_json }
    end

    @client.chat(messages: messages, tools: available_tools)
  end

  def sanitize_history(history)
    history.map do |msg|
      content = msg[:content] || msg["content"]
      if content.to_s.start_with?("{") && content.to_s.include?("name")
        begin
          parsed = JSON.parse(content)
          content = "Requested: #{parsed['name']} with #{parsed['parameters'] || parsed['arguments']}"
        rescue JSON::ParserError
          content = content.to_s.gsub(/[{}]/, "")
        end
      end
      { role: msg[:role] || msg["role"], content: content }
    end
  end

  def self.tool(name, desc, props = {}, req = [])
    params = { type: "object", properties: props }
    params[:required] = req if req.any?
    { type: "function", function: { name: name.to_s, description: desc, parameters: params } }
  end

  def available_tools
    self.class.all_tools
  end

  def self.all_tools
    @all_tools ||= (CATEGORY_TOOLS + EXPENSE_TOOLS + INCOME_TOOLS + BILL_TOOLS +
      LOAN_TOOLS + BUDGET_TOOLS + INVESTMENT_TOOLS + QUERY_TOOLS + DEBT_TOOLS).freeze
  end

  CATEGORY_TOOLS = [
    tool(:create_category, "Create a new category for expenses, income, bills, or loans.", {
      name: { type: "string", description: "Category name." },
      category_type: { type: "string", enum: %w[expense income bill loan emi] },
      icon: { type: "string", description: "Lucide icon name. Default: wallet." },
      color: { type: "string", description: "Hex color. Default: #6366f1." }
    }, %w[name category_type]),
    tool(:list_categories, "List all categories the user has, optionally filtered by type.", {
      category_type: { type: "string", enum: %w[expense income bill loan emi], description: "Optional filter." }
    }),
    tool(:delete_category, "Delete a category by ID. Will fail if it has associated records.", {
      id: { type: "integer", description: "Category ID." }
    }, %w[id])
  ].freeze

  EXPENSE_TOOLS = [
    tool(:create_expense, "Log a new expense. Use for spending, buying, or paying expenses.", {
      amount: { type: "number", description: "Amount in INR." },
      category_name: { type: "string", description: "Category name." },
      payment_method: { type: "string", enum: %w[cash credit_card debit_card upi net_banking other] },
      expense_date: { type: "string", description: "YYYY-MM-DD. Default is today." },
      description: { type: "string", description: "Brief description." }
    }, %w[amount category_name payment_method description]),
    tool(:list_expenses, "List expenses for a given month and year, or search by term.", {
      month: { type: "integer", description: "Month number (1-12). Default: current month." },
      year: { type: "integer", description: "Year. Default: current year." },
      search: { type: "string", description: "Optional search term for description." },
      category_name: { type: "string", description: "Optional filter by category name." },
      limit: { type: "integer", description: "Max results. Default: 20." }
    }),
    tool(:update_expense, "Update an existing expense's amount, description, category, date, or payment method.", {
      id: { type: "integer", description: "Expense ID." },
      amount: { type: "number", description: "New amount in INR." },
      description: { type: "string", description: "New description." },
      category_name: { type: "string", description: "New category name." },
      payment_method: { type: "string", enum: %w[cash credit_card debit_card upi net_banking other] },
      expense_date: { type: "string", description: "New date YYYY-MM-DD." }
    }, %w[id]),
    tool(:delete_expense, "Delete an expense by ID.", { id: { type: "integer", description: "Expense ID." } }, %w[id])
  ].freeze

  INCOME_TOOLS = [
    tool(:create_income, "Record income from salary, freelance, investments, etc.", {
      source: { type: "string", description: "Income source name." },
      amount: { type: "number", description: "Amount in INR." },
      income_date: { type: "string", description: "YYYY-MM-DD. Default: today." },
      frequency: { type: "string", enum: %w[weekly monthly quarterly yearly one_time], description: "Default: one_time." },
      is_recurring: { type: "boolean", description: "Whether this is a recurring income template." },
      notes: { type: "string", description: "Optional notes." }
    }, %w[source amount]),
    tool(:list_incomes, "List incomes for a given month/year.", { month: { type: "integer" }, year: { type: "integer" } }),
    tool(:update_income, "Update an income record.", {
      id: { type: "integer", description: "Income ID." }, source: { type: "string" }, amount: { type: "number" }, notes: { type: "string" }
    }, %w[id]),
    tool(:delete_income, "Delete an income record by ID.", { id: { type: "integer" } }, %w[id]),
    tool(:toggle_income_received, "Toggle whether an income has been received.", { id: { type: "integer" } }, %w[id])
  ].freeze

  BILL_TOOLS = [
    tool(:create_bill, "Create a new monthly bill template.", {
      name: { type: "string", description: "Bill name." },
      amount: { type: "number", description: "Amount in INR." },
      category_name: { type: "string", description: "Category name." },
      due_date: { type: "integer", description: "Due day of month (1-31)." },
      reminder_days: { type: "integer", description: "Days before due to remind. Default: 3." },
      notes: { type: "string" }
    }, %w[name amount category_name due_date]),
    tool(:list_bills, "List all active monthly bills.", { show_paid: { type: "boolean", description: "Include paid bills. Default: false." } }),
    tool(:pay_bill, "Mark an active monthly bill as paid.", { bill_id: { type: "integer", description: "Database ID of the bill." } }, %w[bill_id]),
    tool(:delete_bill, "Delete a monthly bill by ID.", { id: { type: "integer" } }, %w[id])
  ].freeze

  LOAN_TOOLS = [
    tool(:create_loan, "Record a new loan (home, car, personal, etc.) with EMI schedule.", {
      name: { type: "string", description: "Loan name." },
      category_name: { type: "string", description: "Category. Use 'Home Loan' / 'Vehicle Loan' / 'Personal Loan'." },
      principal_amount: { type: "number", description: "Total principal in INR." },
      interest_rate: { type: "number", description: "Annual interest rate in percent (e.g. 8.5)." },
      tenure_months: { type: "integer", description: "Tenure in months." },
      start_date: { type: "string", description: "Start date YYYY-MM-DD." },
      lender: { type: "string", description: "Optional lender name." },
      loan_type: { type: "string", enum: %w[home car personal education business gold other], description: "Default: personal." }
    }, %w[name category_name principal_amount interest_rate tenure_months start_date]),
    tool(:list_loans, "List all active loans with outstanding balance.", {}),
    tool(:pay_emi, "Mark an EMI as paid for a given month.", {
      loan_id: { type: "integer", description: "Loan ID." },
      emi_number: { type: "integer", description: "EMI number to mark paid." },
      paid_date: { type: "string", description: "YYYY-MM-DD. Default: today." }
    }, %w[loan_id emi_number]),
    tool(:delete_loan, "Delete a loan by ID.", { id: { type: "integer" } }, %w[id])
  ].freeze

  BUDGET_TOOLS = [
    tool(:create_budget, "Set a spending budget for a category in a given month/year.", {
      category_name: { type: "string", description: "Category name." },
      amount: { type: "number", description: "Budget amount in INR." },
      month: { type: "integer", description: "Month (1-12). Default: current." },
      year: { type: "integer", description: "Year. Default: current." },
      alert_threshold: { type: "integer", description: "Alert at % of budget spent. Default: 80." }
    }, %w[category_name amount]),
    tool(:list_budgets, "List budgets for a given month/year with spending vs budget.", { month: { type: "integer" }, year: { type: "integer" } }),
    tool(:delete_budget, "Delete a budget by ID.", { id: { type: "integer" } }, %w[id])
  ].freeze

  INVESTMENT_TOOLS = [
    tool(:create_investment, "Record an investment (stocks, mutual funds, crypto, etc.).", {
      name: { type: "string", description: "Investment name." },
      asset_class: { type: "string", enum: %w[speculative_intraday non_speculative_fo swing_trading long_term_equity mutual_funds fixed_income crypto elss_80c gold] },
      symbol: { type: "string", description: "Ticker symbol (optional)." },
      quantity: { type: "number", description: "Quantity/units bought." },
      buy_price: { type: "number", description: "Price per unit at purchase." },
      purchase_date: { type: "string", description: "YYYY-MM-DD." },
      current_price: { type: "number", description: "Current market price (optional)." },
      notes: { type: "string" }
    }, %w[name asset_class quantity buy_price purchase_date]),
    tool(:list_investments, "List investments with P&L, optionally filtered by asset class or status.", {
      asset_class: { type: "string" }, status: { type: "string", enum: %w[active realized] }
    }),
    tool(:update_investment, "Update investment details like sell price to realize it.", {
      id: { type: "integer" }, sell_price: { type: "number" }, sell_date: { type: "string" },
      current_price: { type: "number" }, status: { type: "string", enum: %w[active realized] }, notes: { type: "string" }
    }, %w[id]),
    tool(:delete_investment, "Delete an investment record by ID.", { id: { type: "integer" } }, %w[id])
  ].freeze

  QUERY_TOOLS = [
    tool(:get_financial_summary, "Get a comprehensive financial summary for a given month/year including income, expenses, savings, investments, and tax info.", {
      month: { type: "integer" }, year: { type: "integer" }, financial_year: { type: "integer", description: "FY ending year for tax data." }
    }),
    tool(:calculate_tax_with_copilot, "Calculate accurate Indian income tax using the india-itr-copilot engine. Handles F&O losses, surcharge caps, marginal relief, section 288B rounding, and all Chapter VI-A deductions.", {
      financial_year: { type: "integer", description: "Assessment year (e.g., 2026 for FY 2025-26)." },
      gross_salary: { type: "number", description: "Gross salary income in INR." },
      freelance_income: { type: "number", description: "Freelance/business income in INR." },
      interest_income: { type: "number", description: "Interest income from FD/savings in INR." },
      dividend_income: { type: "number", description: "Dividend income in INR." },
      speculative_pnl: { type: "number", description: "P&L from speculative intraday trading." },
      non_speculative_fo_pnl: { type: "number", description: "P&L from F&O trading (non-speculative business income)." },
      stcg_111a: { type: "number", description: "Short-term capital gains u/s 111A." },
      ltcg_112a: { type: "number", description: "Long-term capital gains u/s 112A." },
      crypto_pnl: { type: "number", description: "P&L from crypto/virtual digital assets." },
      deduction_80c: { type: "number", description: "Investments u/s 80C." },
      deduction_80d: { type: "number", description: "Health insurance premium u/s 80D." },
      deduction_80ccd_1b: { type: "number", description: "NPS contribution u/s 80CCD(1B)." },
      deduction_80tta: { type: "number", description: "Savings account interest u/s 80TTA or 80TTB." },
      hra_exemption: { type: "number", description: "HRA exemption amount." },
      home_loan_interest: { type: "number", description: "Home loan interest u/s 24(b)." }
    }, %w[financial_year]),
    tool(:explain_tax_provision, "Explain Indian tax provisions, sections, and concepts in simple language.", {
      section: { type: "string", description: "Tax section or concept (e.g., '80C', '111A', 'marginal relief', 'advance tax')." },
      context: { type: "string", description: "User's specific situation or question context." }
    }, %w[section])
  ].freeze

  DEBT_TOOLS = [
    tool(:debt_overview, "Get the user's debt clearance overview: total/protected/settlement debt, settlement fund, next settlement target, and monthly cashflow split.", {}),
    tool(:settlement_queue, "Show the ranked settlement queue: which account to target next, its stage, priority score and funding progress.", {}),
    tool(:settle_with_amount, "Simulate what can be settled with a lump of cash.", {
      amount: { type: "number", description: "Available capital in INR (e.g. 100000)." }
    }, %w[amount]),
    tool(:debt_forecast, "Project when each settlement becomes fundable and when the user is debt-free, given a monthly settlement allocation.", {
      monthly_allocation: { type: "number", description: "Monthly amount saved towards settlements in INR. Optional." }
    }),
    tool(:compare_settlement_scenarios, "Compare settlement costs at 20/25/30/35/40/45 percent for one account.", {
      settlement_case_id: { type: "integer", description: "Settlement case ID. Optional if account_name is given." },
      account_name: { type: "string", description: "Account or lender name, e.g. 'IDFC'. Optional." }
    }),
    tool(:add_settlement_contribution, "Record money the user is setting aside towards a settlement.", {
      settlement_case_id: { type: "integer", description: "Settlement case ID. Optional if account_name is given." },
      account_name: { type: "string", description: "Account or lender name, e.g. 'IDFC'. Optional." },
      amount: { type: "number", description: "Amount saved in INR." },
      contributed_on: { type: "string", description: "YYYY-MM-DD. Default: today." },
      source: { type: "string", description: "salary / bonus / increment / other." },
      notes: { type: "string" }
    }, %w[amount])
  ].freeze
end
