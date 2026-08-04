module Ai
  class ToolExecutor
    def initialize(user)
      @user = user
    end

    def execute(tool_call)
      case tool_call.name
      when "create_category"  then create_category(tool_call.arguments)
      when "list_categories"  then list_categories(tool_call.arguments)
      when "delete_category"  then delete_category(tool_call.arguments)
      when "create_expense"   then create_expense(tool_call.arguments)
      when "list_expenses"    then list_expenses(tool_call.arguments)
      when "update_expense"   then update_expense(tool_call.arguments)
      when "delete_expense"   then delete_expense(tool_call.arguments)
      when "create_income"    then create_income(tool_call.arguments)
      when "list_incomes"     then list_incomes(tool_call.arguments)
      when "update_income"    then update_income(tool_call.arguments)
      when "delete_income"    then delete_income(tool_call.arguments)
      when "toggle_income_received" then toggle_income_received(tool_call.arguments)
      when "create_bill"      then create_bill(tool_call.arguments)
      when "list_bills"       then list_bills(tool_call.arguments)
      when "pay_bill"         then pay_bill(tool_call.arguments)
      when "delete_bill"      then delete_bill(tool_call.arguments)
      when "create_loan"      then create_loan(tool_call.arguments)
      when "list_loans"       then list_loans(tool_call.arguments)
      when "pay_emi"          then pay_emi(tool_call.arguments)
      when "delete_loan"      then delete_loan(tool_call.arguments)
      when "create_budget"    then create_budget(tool_call.arguments)
      when "list_budgets"     then list_budgets(tool_call.arguments)
      when "delete_budget"    then delete_budget(tool_call.arguments)
      when "create_investment" then create_investment(tool_call.arguments)
      when "list_investments" then list_investments(tool_call.arguments)
      when "update_investment" then update_investment(tool_call.arguments)
      when "delete_investment" then delete_investment(tool_call.arguments)
      when "get_financial_summary" then get_financial_summary(tool_call.arguments)
      when "calculate_tax_with_copilot" then calculate_tax_with_copilot(tool_call.arguments)
      when "explain_tax_provision" then explain_tax_provision(tool_call.arguments)
      else { success: false, message: "Unknown tool: #{tool_call.name}" }
      end
    rescue StandardError => e
      { success: false, message: "Error: #{e.message}" }
    end

    private

    # ── Categories ──────────────────────────────────────────────────────

    def create_category(args)
      cat = @user.categories.create!(
        name: args["name"],
        category_type: args["category_type"],
        icon: args["icon"] || "wallet",
        color: args["color"] || "#6366f1"
      )
      { success: true, message: "Category created", category: { id: cat.id, name: cat.name, type: cat.category_type } }
    end

    def list_categories(args)
      scope = @user.categories
      scope = scope.where(category_type: args["category_type"]) if args["category_type"].present?
      cats = scope.map { |c| { id: c.id, name: c.name, type: c.category_type, icon: c.icon, color: c.color } }
      { success: true, categories: cats }
    end

    def delete_category(args)
      cat = @user.categories.find(args["id"])
      cat.destroy!
      { success: true, message: "Category deleted" }
    end

    # ── Expenses ────────────────────────────────────────────────────────

    def create_expense(args)
      category = resolve_category(args["category_name"])
      expense = @user.expenses.create!(
        amount: args["amount"].to_d,
        category: category,
        payment_method: args["payment_method"],
        expense_date: Date.parse(args["expense_date"] || Date.current.to_s),
        description: args["description"]
      )
      { success: true, message: "Expense logged", expense: { id: expense.id, amount: expense.amount.to_s, category: category.name, date: expense.expense_date.to_s } }
    end

    def list_expenses(args)
      month = args["month"] || Date.current.month
      year  = args["year"]  || Date.current.year
      scope = @user.expenses.includes(:category).for_month(month, year)
      scope = scope.where(categories: { name: args["category_name"] }) if args["category_name"].present?
      scope = scope.search(args["search"]) if args["search"].present?
      scope = scope.limit(args["limit"] || 20)
      expenses = scope.map { |e| { id: e.id, amount: e.amount.to_s, category: e.category.name, description: e.description, date: e.expense_date.to_s, payment_method: e.payment_method } }
      { success: true, expenses: expenses }
    end

    def update_expense(args)
      expense = @user.expenses.find(args["id"])
      attrs = {}
      attrs[:amount] = args["amount"].to_d if args["amount"]
      attrs[:description] = args["description"] if args["description"]
      attrs[:payment_method] = args["payment_method"] if args["payment_method"]
      attrs[:expense_date] = Date.parse(args["expense_date"]) if args["expense_date"]
      attrs[:category] = resolve_category(args["category_name"]) if args["category_name"]
      expense.update!(attrs)
      { success: true, message: "Expense updated", expense: { id: expense.id, amount: expense.amount.to_s } }
    end

    def delete_expense(args)
      @user.expenses.find(args["id"]).destroy!
      { success: true, message: "Expense deleted" }
    end

    # ── Incomes ─────────────────────────────────────────────────────────

    def create_income(args)
      income = @user.incomes.create!(
        source: args["source"],
        amount: args["amount"].to_d,
        income_date: Date.parse(args["income_date"] || Date.current.to_s),
        frequency: args["frequency"] || "one_time",
        is_recurring: args["is_recurring"] || false,
        notes: args["notes"]
      )
      { success: true, message: "Income recorded", income: { id: income.id, source: income.source, amount: income.amount.to_s, date: income.income_date.to_s } }
    end

    def list_incomes(args)
      month = args["month"] || Date.current.month
      year  = args["year"]  || Date.current.year
      incomes = @user.incomes.for_month(month, year).map { |i| { id: i.id, source: i.source, amount: i.amount.to_s, date: i.income_date.to_s, received: i.is_received, frequency: i.frequency } }
      { success: true, incomes: incomes }
    end

    def update_income(args)
      income = @user.incomes.find(args["id"])
      attrs = {}
      attrs[:source] = args["source"] if args["source"]
      attrs[:amount] = args["amount"].to_d if args["amount"]
      attrs[:notes] = args["notes"] if args.key?("notes")
      income.update!(attrs)
      { success: true, message: "Income updated" }
    end

    def delete_income(args)
      @user.incomes.find(args["id"]).destroy!
      { success: true, message: "Income deleted" }
    end

    def toggle_income_received(args)
      income = @user.incomes.find(args["id"])
      income.update!(is_received: !income.is_received)
      { success: true, message: "Income #{income.is_received ? 'marked received' : 'marked pending'}" }
    end

    # ── Bills ───────────────────────────────────────────────────────────

    def create_bill(args)
      category = resolve_category(args["category_name"])
      bill = @user.monthly_bills.create!(
        name: args["name"],
        amount: args["amount"].to_d,
        category: category,
        due_date: args["due_date"],
        reminder_days: args["reminder_days"] || 3,
        notes: args["notes"]
      )
      { success: true, message: "Bill created", bill: { id: bill.id, name: bill.name, amount: bill.amount.to_s } }
    end

    def list_bills(args)
      scope = @user.monthly_bills.active
      scope = @user.monthly_bills if args["show_paid"]
      bills = scope.map { |b| { id: b.id, name: b.name, amount: b.amount.to_s, due_date: b.due_date, paid: b.is_paid, category: b.category.name } }
      { success: true, bills: bills }
    end

    def pay_bill(args)
      bill = @user.monthly_bills.find_by(id: args["bill_id"])
      if bill&.update(is_paid: true)
        { success: true, message: "Bill marked as paid", bill: { id: bill.id, name: bill.name } }
      else
        { success: false, message: "Bill not found" }
      end
    end

    def delete_bill(args)
      @user.monthly_bills.find(args["id"]).destroy!
      { success: true, message: "Bill deleted" }
    end

    # ── Loans ───────────────────────────────────────────────────────────

    def create_loan(args)
      category = resolve_category(args["category_name"])
      loan = @user.loans.create!(
        name: args["name"],
        category: category,
        principal_amount: args["principal_amount"].to_d,
        interest_rate: args["interest_rate"].to_d,
        tenure_months: args["tenure_months"],
        start_date: Date.parse(args["start_date"]),
        lender: args["lender"],
        loan_type: args["loan_type"] || "personal"
      )
      { success: true, message: "Loan created with EMI schedule", loan: { id: loan.id, name: loan.name, emi: loan.emi_amount.to_s, tenure: loan.tenure_months } }
    end

    def list_loans(_args)
      loans = @user.loans.map { |l| { id: l.id, name: l.name, principal: l.principal_amount.to_s, outstanding: l.outstanding_principal.to_s, emi: l.emi_amount.to_s, tenure: l.tenure_months, remaining_emis: l.remaining_emi_count, loan_type: l.loan_type, active: l.is_active } }
      { success: true, loans: loans }
    end

    def pay_emi(args)
      loan = @user.loans.find(args["loan_id"])
      emi = loan.emi_payments.find_by!(emi_number: args["emi_number"])
      emi.update!(is_paid: true, paid_date: Date.parse(args["paid_date"] || Date.current.to_s))
      { success: true, message: "EMI ##{emi.emi_number} marked paid", loan: loan.name, paid_date: emi.paid_date.to_s }
    end

    def delete_loan(args)
      @user.loans.find(args["id"]).destroy!
      { success: true, message: "Loan deleted" }
    end

    # ── Budgets ─────────────────────────────────────────────────────────

    def create_budget(args)
      category = resolve_category(args["category_name"])
      budget = @user.budgets.create!(
        category: category,
        amount: args["amount"].to_d,
        month: args["month"] || Date.current.month,
        year: args["year"] || Date.current.year,
        alert_threshold: args["alert_threshold"] || 80
      )
      { success: true, message: "Budget set", budget: { id: budget.id, category: category.name, amount: budget.amount.to_s, month: budget.month, year: budget.year } }
    end

    def list_budgets(args)
      month = args["month"] || Date.current.month
      year  = args["year"]  || Date.current.year
      budgets = @user.budgets.includes(:category).where(month: month, year: year).map do |b|
        spent = @user.expenses.joins(:category).where(categories: { id: b.category_id }).for_month(month, year).sum(:amount)
        { id: b.id, category: b.category.name, budget: b.amount.to_s, spent: spent.to_s, remaining: (b.amount - spent).to_s, pct: (spent / b.amount.to_f * 100).round(1) }
      end
      { success: true, budgets: budgets }
    end

    def delete_budget(args)
      @user.budgets.find(args["id"]).destroy!
      { success: true, message: "Budget deleted" }
    end

    # ── Investments ─────────────────────────────────────────────────────

    def create_investment(args)
      inv = @user.investments.create!(
        name: args["name"],
        asset_class: args["asset_class"],
        symbol: args["symbol"],
        quantity: args["quantity"].to_d,
        buy_price: args["buy_price"].to_d,
        purchase_date: Date.parse(args["purchase_date"]),
        current_price: args["current_price"]&.to_d,
        notes: args["notes"]
      )
      { success: true, message: "Investment recorded", investment: { id: inv.id, name: inv.name, invested: inv.invested_amount.to_s } }
    end

    def list_investments(args)
      scope = @user.investments
      scope = scope.where(asset_class: args["asset_class"]) if args["asset_class"].present?
      scope = scope.where(status: args["status"]) if args["status"].present?
      investments = scope.map { |i| { id: i.id, name: i.name, asset_class: i.asset_class, invested: i.invested_amount.to_s, current_value: i.current_value.to_s, pnl: i.total_pnl.to_s, pnl_pct: i.pnl_percentage, status: i.status } }
      { success: true, investments: investments }
    end

    def update_investment(args)
      inv = @user.investments.find(args["id"])
      attrs = {}
      attrs[:sell_price] = args["sell_price"].to_d if args["sell_price"]
      attrs[:sell_date] = Date.parse(args["sell_date"]) if args["sell_date"]
      attrs[:current_price] = args["current_price"].to_d if args["current_price"]
      attrs[:status] = args["status"] if args["status"]
      attrs[:notes] = args["notes"] if args.key?("notes")
      attrs[:status] = "realized" if args["sell_price"] && !args.key?("status")
      inv.update!(attrs)
      { success: true, message: "Investment updated", pnl: inv.total_pnl.to_s }
    end

    def delete_investment(args)
      @user.investments.find(args["id"]).destroy!
      { success: true, message: "Investment deleted" }
    end

    # ── Financial Summary ───────────────────────────────────────────────

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
          income: { total: dashboard.dig(:income, :total), received: dashboard.dig(:income, :received), expected: dashboard.dig(:income, :expected) },
          expenses: { total: dashboard.dig(:expenses, :total), count: dashboard.dig(:expenses, :count) },
          bills: { total: dashboard.dig(:bills, :total), paid: dashboard.dig(:bills, :paid), unpaid: dashboard.dig(:bills, :unpaid) },
          emis: { total: dashboard.dig(:emis, :total), paid_count: dashboard.dig(:emis, :paid) },
          net_savings: dashboard.dig(:income, :total).to_d - dashboard.dig(:expenses, :total).to_d - dashboard.dig(:bills, :total).to_d - dashboard.dig(:emis, :total).to_d,
          overall: dashboard[:overall],
          tax: tax ? {
            fy: tax[:financial_year],
            trading_pnl: tax[:trading_summary],
            total_tax_new: tax.dig(:new_regime, :total_tax),
            total_tax_old: tax.dig(:old_regime, :total_tax),
            recommended_regime: tax.dig(:recommendation, :best_regime),
            itr_form: tax.dig(:recommendation, :itr_form)
          } : nil
        }
      }
    end

    def resolve_category(name)
      clean_name = name.to_s.strip
      @user.categories.where("name ILIKE ?", clean_name).first ||
        @user.categories.find_by(name: "Other") ||
        @user.categories.create!(name: clean_name, category_type: "expense")
    end

    def default_fy
      today = Date.current
      if today.month >= 4 && today.month <= 11
        today.year      # Apr-Nov → FY ending this year (previous completed FY)
      elsif today.month == 12
        today.year + 1
      else
        today.year
      end
    end

    # ── Tax Calculation with india-itr-copilot ───────────────────────────

    def calculate_tax_with_copilot(args)
      financial_year = args["financial_year"] || default_fy
      
      # Option 1: Call Python FastAPI service directly (preferred if running)
      copilot_host = ENV.fetch("ITR_SERVICE_HOST", "http://localhost:8000")
      
      input_data = {
        assessment_year: "AY#{financial_year}-#{(financial_year % 100) + 1}",
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

      begin
        require "net/http"
        require "uri"
        
        uri = URI("#{copilot_host}/compare-regimes")
        req = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
        req.body = input_data.to_json
        
        res = Net::HTTP.start(uri.hostname, uri.port, read_timeout: 30) do |http|
          http.request(req)
        end
        
        if res.is_a?(Net::HTTPSuccess)
          result = JSON.parse(res.body)
          return {
            success: true,
            engine: "india-itr-copilot",
            assessment_year: result["assessment_year"],
            new_regime: result["new_regime"],
            old_regime: result["old_regime"],
            recommendation: result["recommendation"],
            marginal_relief_applied: result["marginal_relief_applied"],
            section_288b_rounding_applied: result["section_288b_rounding_applied"],
            f_o_loss_setoff: result["f_o_loss_setoff"],
            surcharge_cap_applied: result["surcharge_cap_applied"]
          }
        end
      rescue StandardError => e
        Rails.logger.warn "[Copilot HTTP] Error: #{e.message}, falling back to Ruby calculator"
      end

      # Fallback: Use existing Ruby tax calculator
      summary = get_financial_summary({ "financial_year" => financial_year })
      {
        success: true,
        engine: "ruby_fallback",
        message: "Using Ruby tax calculator (india-itr-copilot service unavailable)",
        tax_result: summary[:tax],
        fallback_used: true
      }
    end

    def explain_tax_provision(args)
      section = args["section"]
      context = args["context"]

      prompt = <<~PROMPT
        You are a helpful Indian tax assistant. Explain the following tax provision in simple, clear language:

        Section/Concept: #{section}
        User Context: #{context || "General inquiry"}

        Provide:
        1. What this section/concept means in plain English
        2. Who it applies to
        3. Key limits, thresholds, or conditions
        4. A practical example if relevant
        5. Any common mistakes or pitfalls to avoid

        Keep the explanation concise but complete. Use INR (₹) for amounts.
      PROMPT

      config = Ollama::Config.new
      config.base_url = ENV.fetch("OLLAMA_HOST", "http://localhost:11434")
      config.api_key = ENV["OLLAMA_API_KEY"]
      config.model = ENV.fetch("OLLAMA_MODEL", "qwen3.5:4b")
      config.provider = :ollama
      config.temperature = 0.3
      config.timeout = 60

      client = Ollama::Client.new(config: config)

      response = client.chat(messages: [{ role: "user", content: prompt }])

      {
        success: true,
        section: section,
        explanation: response.message.content,
        disclaimer: "This is general guidance. Consult a CA for personalized tax advice."
      }
    rescue StandardError => e
      {
        success: false,
        message: "Error explaining provision: #{e.message}",
        suggestion: "Try rephrasing your question or ask about a specific section number."
      }
    end
  end
end
