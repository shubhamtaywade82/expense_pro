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
  end
end
