class AiChatService
  def initialize(user)
    @user = user
    config = Ollama::Config.new
    config.base_url = ENV.fetch("OLLAMA_HOST", "http://localhost:11434")
    config.api_key = ENV["OLLAMA_API_KEY"]
    config.model = ENV.fetch("OLLAMA_MODEL", "qwen3.5:4b")
    config.provider = :ollama
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

  def available_tools
    CATEGORY_TOOLS + EXPENSE_TOOLS + INCOME_TOOLS + BILL_TOOLS +
      LOAN_TOOLS + BUDGET_TOOLS + INVESTMENT_TOOLS + QUERY_TOOLS
  end

  CATEGORY_TOOLS = [
    {
      type: "function",
      function: {
        name: "create_category",
        description: "Create a new category for expenses, income, bills, or loans.",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string", description: "Category name." },
            category_type: { type: "string", enum: %w[expense income bill loan emi] },
            icon: { type: "string", description: "Lucide icon name. Default: wallet." },
            color: { type: "string", description: "Hex color. Default: #6366f1." }
          },
          required: %w[name category_type]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "list_categories",
        description: "List all categories the user has, optionally filtered by type.",
        parameters: {
          type: "object",
          properties: {
            category_type: { type: "string", enum: %w[expense income bill loan emi], description: "Optional filter." }
          }
        }
      }
    },
    {
      type: "function",
      function: {
        name: "delete_category",
        description: "Delete a category by ID. Will fail if it has associated records.",
        parameters: {
          type: "object",
          properties: {
            id: { type: "integer", description: "Category ID." }
          },
          required: %w[id]
        }
      }
    }
  ].freeze

  EXPENSE_TOOLS = [
    {
      type: "function",
      function: {
        name: "create_expense",
        description: "Log a new expense. Use for spending, buying, or paying expenses.",
        parameters: {
          type: "object",
          properties: {
            amount: { type: "number", description: "Amount in INR." },
            category_name: { type: "string", description: "Category name." },
            payment_method: { type: "string", enum: %w[cash credit_card debit_card upi net_banking other] },
            expense_date: { type: "string", description: "YYYY-MM-DD. Default is today." },
            description: { type: "string", description: "Brief description." }
          },
          required: %w[amount category_name payment_method description]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "list_expenses",
        description: "List expenses for a given month and year, or search by term.",
        parameters: {
          type: "object",
          properties: {
            month: { type: "integer", description: "Month number (1-12). Default: current month." },
            year: { type: "integer", description: "Year. Default: current year." },
            search: { type: "string", description: "Optional search term for description." },
            category_name: { type: "string", description: "Optional filter by category name." },
            limit: { type: "integer", description: "Max results. Default: 20." }
          }
        }
      }
    },
    {
      type: "function",
      function: {
        name: "update_expense",
        description: "Update an existing expense's amount, description, category, date, or payment method.",
        parameters: {
          type: "object",
          properties: {
            id: { type: "integer", description: "Expense ID." },
            amount: { type: "number", description: "New amount in INR." },
            description: { type: "string", description: "New description." },
            category_name: { type: "string", description: "New category name." },
            payment_method: { type: "string", enum: %w[cash credit_card debit_card upi net_banking other] },
            expense_date: { type: "string", description: "New date YYYY-MM-DD." }
          },
          required: %w[id]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "delete_expense",
        description: "Delete an expense by ID.",
        parameters: {
          type: "object",
          properties: {
            id: { type: "integer", description: "Expense ID." }
          },
          required: %w[id]
        }
      }
    }
  ].freeze

  INCOME_TOOLS = [
    {
      type: "function",
      function: {
        name: "create_income",
        description: "Record income from salary, freelance, investments, etc.",
        parameters: {
          type: "object",
          properties: {
            source: { type: "string", description: "Income source name." },
            amount: { type: "number", description: "Amount in INR." },
            income_date: { type: "string", description: "YYYY-MM-DD. Default: today." },
            frequency: { type: "string", enum: %w[weekly monthly quarterly yearly one_time], description: "Default: one_time." },
            is_recurring: { type: "boolean", description: "Whether this is a recurring income template." },
            notes: { type: "string", description: "Optional notes." }
          },
          required: %w[source amount]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "list_incomes",
        description: "List incomes for a given month/year.",
        parameters: {
          type: "object",
          properties: {
            month: { type: "integer" },
            year: { type: "integer" }
          }
        }
      }
    },
    {
      type: "function",
      function: {
        name: "update_income",
        description: "Update an income record.",
        parameters: {
          type: "object",
          properties: {
            id: { type: "integer", description: "Income ID." },
            source: { type: "string" },
            amount: { type: "number" },
            notes: { type: "string" }
          },
          required: %w[id]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "delete_income",
        description: "Delete an income record by ID.",
        parameters: {
          type: "object",
          properties: {
            id: { type: "integer" }
          },
          required: %w[id]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "toggle_income_received",
        description: "Toggle whether an income has been received.",
        parameters: {
          type: "object",
          properties: {
            id: { type: "integer" }
          },
          required: %w[id]
        }
      }
    }
  ].freeze

  BILL_TOOLS = [
    {
      type: "function",
      function: {
        name: "create_bill",
        description: "Create a new monthly bill template.",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string", description: "Bill name." },
            amount: { type: "number", description: "Amount in INR." },
            category_name: { type: "string", description: "Category name." },
            due_date: { type: "integer", description: "Due day of month (1-31)." },
            reminder_days: { type: "integer", description: "Days before due to remind. Default: 3." },
            notes: { type: "string" }
          },
          required: %w[name amount category_name due_date]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "list_bills",
        description: "List all active monthly bills.",
        parameters: {
          type: "object",
          properties: {
            show_paid: { type: "boolean", description: "Include paid bills. Default: false." }
          }
        }
      }
    },
    {
      type: "function",
      function: {
        name: "pay_bill",
        description: "Mark an active monthly bill as paid.",
        parameters: {
          type: "object",
          properties: {
            bill_id: { type: "integer", description: "Database ID of the bill." }
          },
          required: %w[bill_id]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "delete_bill",
        description: "Delete a monthly bill by ID.",
        parameters: {
          type: "object",
          properties: {
            id: { type: "integer" }
          },
          required: %w[id]
        }
      }
    }
  ].freeze

  LOAN_TOOLS = [
    {
      type: "function",
      function: {
        name: "create_loan",
        description: "Record a new loan (home, car, personal, etc.) with EMI schedule.",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string", description: "Loan name." },
            category_name: { type: "string", description: "Category. Use 'Home Loan' / 'Vehicle Loan' / 'Personal Loan'." },
            principal_amount: { type: "number", description: "Total principal in INR." },
            interest_rate: { type: "number", description: "Annual interest rate in percent (e.g. 8.5)." },
            tenure_months: { type: "integer", description: "Tenure in months." },
            start_date: { type: "string", description: "Start date YYYY-MM-DD." },
            lender: { type: "string", description: "Optional lender name." },
            loan_type: { type: "string", enum: %w[home car personal education business gold other], description: "Default: personal." }
          },
          required: %w[name category_name principal_amount interest_rate tenure_months start_date]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "list_loans",
        description: "List all active loans with outstanding balance.",
        parameters: { type: "object", properties: {} }
      }
    },
    {
      type: "function",
      function: {
        name: "pay_emi",
        description: "Mark an EMI as paid for a given month.",
        parameters: {
          type: "object",
          properties: {
            loan_id: { type: "integer", description: "Loan ID." },
            emi_number: { type: "integer", description: "EMI number to mark paid." },
            paid_date: { type: "string", description: "YYYY-MM-DD. Default: today." }
          },
          required: %w[loan_id emi_number]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "delete_loan",
        description: "Delete a loan by ID.",
        parameters: {
          type: "object",
          properties: { id: { type: "integer" } },
          required: %w[id]
        }
      }
    }
  ].freeze

  BUDGET_TOOLS = [
    {
      type: "function",
      function: {
        name: "create_budget",
        description: "Set a spending budget for a category in a given month/year.",
        parameters: {
          type: "object",
          properties: {
            category_name: { type: "string", description: "Category name." },
            amount: { type: "number", description: "Budget amount in INR." },
            month: { type: "integer", description: "Month (1-12). Default: current." },
            year: { type: "integer", description: "Year. Default: current." },
            alert_threshold: { type: "integer", description: "Alert at % of budget spent. Default: 80." }
          },
          required: %w[category_name amount]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "list_budgets",
        description: "List budgets for a given month/year with spending vs budget.",
        parameters: {
          type: "object",
          properties: {
            month: { type: "integer" },
            year: { type: "integer" }
          }
        }
      }
    },
    {
      type: "function",
      function: {
        name: "delete_budget",
        description: "Delete a budget by ID.",
        parameters: {
          type: "object",
          properties: { id: { type: "integer" } },
          required: %w[id]
        }
      }
    }
  ].freeze

  INVESTMENT_TOOLS = [
    {
      type: "function",
      function: {
        name: "create_investment",
        description: "Record an investment (stocks, mutual funds, crypto, etc.).",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string", description: "Investment name." },
            asset_class: { type: "string", enum: %w[speculative_intraday non_speculative_fo swing_trading long_term_equity mutual_funds fixed_income crypto elss_80c gold] },
            symbol: { type: "string", description: "Ticker symbol (optional)." },
            quantity: { type: "number", description: "Quantity/units bought." },
            buy_price: { type: "number", description: "Price per unit at purchase." },
            purchase_date: { type: "string", description: "YYYY-MM-DD." },
            current_price: { type: "number", description: "Current market price (optional)." },
            notes: { type: "string" }
          },
          required: %w[name asset_class quantity buy_price purchase_date]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "list_investments",
        description: "List investments with P&L, optionally filtered by asset class or status.",
        parameters: {
          type: "object",
          properties: {
            asset_class: { type: "string" },
            status: { type: "string", enum: %w[active realized] }
          }
        }
      }
    },
    {
      type: "function",
      function: {
        name: "update_investment",
        description: "Update investment details like sell price to realize it.",
        parameters: {
          type: "object",
          properties: {
            id: { type: "integer" },
            sell_price: { type: "number" },
            sell_date: { type: "string" },
            current_price: { type: "number" },
            status: { type: "string", enum: %w[active realized] },
            notes: { type: "string" }
          },
          required: %w[id]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "delete_investment",
        description: "Delete an investment record by ID.",
        parameters: {
          type: "object",
          properties: { id: { type: "integer" } },
          required: %w[id]
        }
      }
    }
  ].freeze

  QUERY_TOOLS = [
    {
      type: "function",
      function: {
        name: "get_financial_summary",
        description: "Get a comprehensive financial summary for a given month/year including income, expenses, savings, investments, and tax info.",
        parameters: {
          type: "object",
          properties: {
            month: { type: "integer" },
            year: { type: "integer" },
            financial_year: { type: "integer", description: "FY ending year for tax data." }
          }
        }
      }
    },
    {
      type: "function",
      function: {
        name: "calculate_tax_with_copilot",
        description: "Calculate accurate Indian income tax using the india-itr-copilot engine. Handles F&O losses, surcharge caps, marginal relief on 87A rebate and surcharge boundaries, section 288B rounding, and all Chapter VI-A deductions. Returns comparison of old vs new regime with precise tax liability.",
        parameters: {
          type: "object",
          properties: {
            financial_year: { type: "integer", description: "Assessment year (e.g., 2026 for FY 2025-26)." },
            gross_salary: { type: "number", description: "Gross salary income in INR." },
            freelance_income: { type: "number", description: "Freelance/business income in INR." },
            interest_income: { type: "number", description: "Interest income from FD/savings in INR." },
            dividend_income: { type: "number", description: "Dividend income in INR." },
            speculative_pnl: { type: "number", description: "P&L from speculative intraday trading." },
            non_speculative_fo_pnl: { type: "number", description: "P&L from F&O trading (non-speculative business income)." },
            stcg_111a: { type: "number", description: "Short-term capital gains u/s 111A (equity sold within 1 year)." },
            ltcg_112a: { type: "number", description: "Long-term capital gains u/s 112A (equity sold after 1 year, above 1.25L exemption)." },
            crypto_pnl: { type: "number", description: "P&L from crypto/virtual digital assets." },
            deduction_80c: { type: "number", description: "Investments u/s 80C (ELSS, PPF, EPF, home loan principal, etc.)." },
            deduction_80d: { type: "number", description: "Health insurance premium u/s 80D (self/family + parents)." },
            deduction_80ccd_1b: { type: "number", description: "NPS contribution u/s 80CCD(1B) (additional 50k over 80C)." },
            deduction_80tta: { type: "number", description: "Savings account interest u/s 80TTA (max 10k) or 80TTB for senior citizens." },
            hra_exemption: { type: "number", description: "HRA exemption amount (calculated separately)." },
            home_loan_interest: { type: "number", description: "Home loan interest u/s 24(b) (max 2L for self-occupied)." }
          },
          required: ["financial_year"]
        }
      }
    },
    {
      type: "function",
      function: {
        name: "explain_tax_provision",
        description: "Explain Indian tax provisions, sections, and concepts in simple language. Use this when user asks about tax rules, deductions, exemptions, or filing requirements.",
        parameters: {
          type: "object",
          properties: {
            section: { type: "string", description: "Tax section or concept (e.g., '80C', '111A', 'marginal relief', 'surcharge', 'advance tax')." },
            context: { type: "string", description: "User's specific situation or question context." }
          },
          required: ["section"]
        }
      }
    }
  ].freeze

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
end
