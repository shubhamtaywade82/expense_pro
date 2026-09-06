# frozen_string_literal: true

module Ai
  module Tools
    class CoreHandler
      def initialize(user)
        @user = user
      end

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
        updates = {}
        updates[:amount] = args["amount"].to_d if args["amount"].present?
        updates[:description] = args["description"] if args["description"].present?
        updates[:category] = resolve_category(args["category_name"]) if args["category_name"].present?
        updates[:payment_method] = args["payment_method"] if args["payment_method"].present?
        updates[:expense_date] = Date.parse(args["expense_date"]) if args["expense_date"].present?
        expense.update!(updates)
        { success: true, message: "Expense updated", expense: { id: expense.id, amount: expense.amount.to_s, category: expense.category.name } }
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
        { success: true, message: "Income recorded", income: { id: income.id, source: income.source, amount: income.amount.to_s } }
      end

      def list_incomes(args)
        month = args["month"] || Date.current.month
        year  = args["year"]  || Date.current.year
        incomes = @user.incomes.for_month(month, year).map do |i|
          { id: i.id, source: i.source, amount: i.amount.to_s, date: i.income_date.to_s, received: i.is_received, recurring: i.is_recurring }
        end
        { success: true, incomes: incomes }
      end

      def update_income(args)
        income = @user.incomes.find(args["id"])
        updates = {}
        updates[:source] = args["source"] if args["source"].present?
        updates[:amount] = args["amount"].to_d if args["amount"].present?
        updates[:notes]  = args["notes"] if args["notes"].present?
        income.update!(updates)
        { success: true, message: "Income updated" }
      end

      def delete_income(args)
        @user.incomes.find(args["id"]).destroy!
        { success: true, message: "Income deleted" }
      end

      def toggle_income_received(args)
        income = @user.incomes.find(args["id"])
        income.update!(is_received: !income.is_received)
        { success: true, message: "Income marked as #{income.is_received ? 'received' : 'pending'}" }
      end

      # ── Bills ───────────────────────────────────────────────────────────

      def create_bill(args)
        category = resolve_category(args["category_name"], default_type: "bill")
        bill = @user.bills.create!(
          name: args["name"],
          amount: args["amount"].to_d,
          category: category,
          due_date: args["due_date"].to_i,
          reminder_days: args["reminder_days"] || 3,
          notes: args["notes"]
        )
        { success: true, message: "Bill created", bill: { id: bill.id, name: bill.name, amount: bill.amount.to_s } }
      end

      def list_bills(args)
        scope = @user.bills.active.includes(:category)
        scope = scope.where(is_paid: false) unless args["show_paid"]
        bills = scope.map { |b| { id: b.id, name: b.name, amount: b.amount.to_s, due_date: b.due_date, paid: b.is_paid, category: b.category.name } }
        { success: true, bills: bills }
      end

      def pay_bill(args)
        bill = @user.bills.find(args["bill_id"])
        bill.mark_paid!
        { success: true, message: "Bill marked as paid" }
      end

      def delete_bill(args)
        @user.bills.find(args["id"]).destroy!
        { success: true, message: "Bill deleted" }
      end

      # ── Loans ───────────────────────────────────────────────────────────

      def create_loan(args)
        category = resolve_category(args["category_name"], default_type: "loan")
        loan = @user.loans.create!(
          name: args["name"],
          category: category,
          principal_amount: args["principal_amount"].to_d,
          interest_rate: args["interest_rate"].to_d,
          tenure_months: args["tenure_months"].to_i,
          start_date: Date.parse(args["start_date"]),
          lender: args["lender"],
          loan_type: args["loan_type"] || "personal"
        )
        { success: true, message: "Loan created", loan: { id: loan.id, name: loan.name, emi: loan.emi_amount.to_s, total: loan.total_amount.to_s } }
      end

      def list_loans(_args)
        loans = @user.loans.active.includes(:category).map do |l|
          { id: l.id, name: l.name, type: l.loan_type, principal: l.principal_amount.to_s, balance: l.outstanding_balance.to_s, emi: l.emi_amount.to_s, lender: l.lender }
        end
        { success: true, loans: loans }
      end

      def pay_emi(args)
        loan = @user.loans.find(args["loan_id"])
        schedule = loan.emi_schedules.find_by!(emi_number: args["emi_number"])
        schedule.mark_paid!(payment_date: Date.parse(args["paid_date"] || Date.current.to_s))
        { success: true, message: "EMI ##{schedule.emi_number} marked as paid", remaining_emis: loan.remaining_emis }
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
        { success: true, message: "Budget set", budget: { id: budget.id, category: category.name, amount: budget.amount.to_s } }
      end

      def list_budgets(args)
        month = args["month"] || Date.current.month
        year  = args["year"]  || Date.current.year
        budgets = @user.budgets.for_month(month, year).includes(:category).map do |b|
          spent = b.spent_amount
          { id: b.id, category: b.category.name, budget: b.amount.to_s, spent: spent.to_s, remaining: (b.amount - spent).to_s, percent: b.spent_percentage }
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
        investments = scope.map do |i|
          { id: i.id, name: i.name, asset_class: i.asset_class, symbol: i.symbol, qty: i.quantity.to_s, buy_price: i.buy_price.to_s, current_price: i.current_price&.to_s, pnl: i.pnl&.to_s, pnl_pct: i.pnl_percentage&.to_s, status: i.status }
        end
        { success: true, investments: investments }
      end

      def update_investment(args)
        inv = @user.investments.find(args["id"])
        updates = {}
        updates[:sell_price]    = args["sell_price"].to_d if args["sell_price"].present?
        updates[:sell_date]     = Date.parse(args["sell_date"]) if args["sell_date"].present?
        updates[:current_price] = args["current_price"].to_d if args["current_price"].present?
        updates[:status]        = args["status"] if args["status"].present?
        updates[:notes]         = args["notes"] if args["notes"].present?
        inv.update!(updates)
        { success: true, message: "Investment updated" }
      end

      def delete_investment(args)
        @user.investments.find(args["id"]).destroy!
        { success: true, message: "Investment deleted" }
      end

      private

      def resolve_category(name, default_type: "expense")
        clean = name.to_s.strip
        @user.categories.where("name ILIKE ?", clean).first ||
          @user.categories.find_by(name: "Other") ||
          @user.categories.create!(name: clean, category_type: default_type)
      end
    end
  end
end
