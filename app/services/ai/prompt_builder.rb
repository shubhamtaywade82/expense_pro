# frozen_string_literal: true

module Ai
  class PromptBuilder
    def initialize(user)
      @user = user
    end

    def build
      now = Time.current
      dashboard = DashboardService.new(@user, month: now.month, year: now.year).overview
      month_incomes = @user.incomes.for_month(now.month, now.year).recent_first

      <<~SYSTEM
        You are ExpensePro AI, a premium personal finance assistant.
        Use the tools provided to take actions on behalf of the user.

        Current Local Time: #{now.strftime("%A, %B %d, %Y, %I:%M %p")}

        User's Current Financial Data (#{now.strftime("%B %Y")}):
        - Total Income: ₹#{dashboard.dig(:income, :total)} (#{dashboard.dig(:income, :received)} received, #{dashboard.dig(:income, :expected)} expected)
        - Total Expenses: ₹#{dashboard.dig(:expenses, :total)}
        - Monthly Bills: ₹#{dashboard.dig(:bills, :total)} total (#{dashboard.dig(:bills, :paid)} paid, #{dashboard.dig(:bills, :unpaid)} pending)
        - Loan EMIs: ₹#{dashboard.dig(:emis, :total)}
        - Net Savings (This Month): ₹#{calculate_net_savings(dashboard)}

        Income Sources (This Month):#{" "}
        #{formatted_incomes(month_incomes)}

        Overall / Life-to-Date:
        - Total Income: ₹#{dashboard.dig(:overall, :totalIncome)}
        - Total Expenses: ₹#{dashboard.dig(:overall, :totalExpense)}
        - Total Loan EMIs Paid: ₹#{dashboard.dig(:overall, :totalEmiPaid)}
        - Net Balance (Life-to-Date Savings): ₹#{dashboard.dig(:overall, :netBalance)}

        Employment History:
        #{formatted_employments}

        Categories:
        #{formatted_categories}

        Active Monthly Bills:
        #{formatted_bills}

        Active Loans:
        #{formatted_loans}

        Debt Clearance Overview:
        #{formatted_debt_clearance}

        Settlement Pipeline (ranked by DebtQueueRanker):
        #{formatted_settlement_pipeline}

        Active Budgets (This Month):
        #{formatted_budgets}

        Investments:
        #{formatted_investments}

        Recent Expenses:
        #{formatted_expenses}

        Available Tools:
        1. create_category(name, category_type, icon?, color?) — Add a spending/income category.
        2. list_categories(category_type?) — View all categories.
        3. delete_category(id) — Remove a category.
        4. create_expense(amount, category_name, payment_method, expense_date?, description?) — Log an expense.
        5. list_expenses(month?, year?, category_name?, search?, limit?) — View expenses.
        6. update_expense(id, amount?, description?, category_name?, expense_date?, payment_method?) — Edit an expense.
        7. delete_expense(id) — Remove an expense.
        8. create_income(source, amount, income_date?, income_type?, frequency?, is_recurring?, notes?) — Record income.
        9. list_incomes(month?, year?) — View income entries.
        10. update_income(id, source?, amount?, notes?) — Edit income.
        11. delete_income(id) — Remove income.
        12. toggle_income_received(id) — Mark income received/pending.
        13. create_bill(name, amount, due_date, category_name?, reminder_days?, notes?) — Add a bill.
        14. list_bills(show_paid?) — View upcoming bills.
        15. pay_bill(bill_id) — Mark a bill paid.
        16. delete_bill(id) — Remove a bill.
        17. create_loan(name, principal_amount, interest_rate, tenure_months, start_date, category_name?, lender?, loan_type?) — Add a loan (auto-generates EMI schedule).
        18. list_loans() — View all loans with outstanding balance.
        19. pay_emi(loan_id, emi_number, paid_date?) — Record an EMI payment.
        20. delete_loan(id) — Remove a loan.
        21. create_budget(category_name, amount, month?, year?, alert_threshold?) — Set a monthly budget.
        22. list_budgets(month?, year?) — View budgets with spent vs remaining.
        23. delete_budget(id) — Remove a budget.
        24. create_investment(name, asset_class, symbol?, quantity, buy_price, purchase_date, current_price?, notes?) — Record an investment.
        25. list_investments(asset_class?, status?) — View investments with P&L.
        26. update_investment(id, sell_price?, sell_date?, current_price?, status?, notes?) — Update investment (sell/update price).
        27. delete_investment(id) — Remove an investment.
        28. get_financial_summary(month?, year?, financial_year?) — Full financial snapshot with optional tax estimate.
        29. debt_overview() — Total/protected/settlement debt, settlement fund, next target, cashflow.
        30. settlement_queue() — Ranked settlement pipeline with stages, scores and funding progress.
        31. settle_with_amount(amount) — "What can I settle with ₹X?" simulator.
        32. debt_forecast(monthly_allocation?) — Projected settlement dates and debt-free date.
        33. compare_settlement_scenarios(settlement_case_id? | account_name?) — 20-45% settlement cost ladder for one account.
        34. add_settlement_contribution(amount, settlement_case_id? | account_name?, contributed_on?, source?, notes?) — Save money towards a settlement.

        Instructions:
        - Use these tools to manage the user's finances. Financial context is already in this prompt.
        - DO NOT call tools to fetch data that is already provided above.
        - Be proactive: suggest logging expenses, paying bills, or setting budgets when appropriate.
        - For tax questions, use get_financial_summary with the relevant financial year.
        - For debt questions, use the debt tools; settlement amounts always come from offers/scenario math, never from the raw claim amount.
        - If uncertain about a parameter, ask the user.
      SYSTEM
    end

    private

    def calculate_net_savings(dashboard)
      dashboard.dig(:income, :total).to_d -
        dashboard.dig(:expenses, :total).to_d -
        dashboard.dig(:bills, :total).to_d -
        dashboard.dig(:emis, :total).to_d
    end

    def formatted_categories
      @user.categories.map { |c| "- #{c.name} (#{c.category_type})" }.join("\n")
    end

    def formatted_bills
      @user.monthly_bills.active.map { |b| "- ID: #{b.id}, Name: #{b.name}, Amount: ₹#{b.amount}, Paid: #{b.is_paid ? 'Yes' : 'No'}" }.join("\n")
    end

    def formatted_expenses
      @user.expenses.includes(:category).recent_first.limit(5).map { |e| "- #{e.expense_date}: ₹#{e.amount} for #{e.description || e.category.name}" }.join("\n")
    end

    def formatted_loans
      loans = @user.loans.active.map { |l| "- #{l.name}: ₹#{l.outstanding_principal} outstanding, EMI ₹#{l.emi_amount}, #{l.remaining_emi_count} remaining" }
      loans.any? ? loans.join("\n") : "- No active loans"
    end

    def formatted_budgets
      budgets = @user.budgets.includes(:category).where(month: Date.current.month, year: Date.current.year)
      return "- No budgets set for this month" if budgets.empty?
      budgets.map do |b|
        spent = @user.expenses.joins(:category).where(categories: { id: b.category_id }).for_month(b.month, b.year).sum(:amount)
        pct = b.amount.positive? ? (spent / b.amount * 100).round(1) : 0
        "- #{b.category.name}: ₹#{b.amount} budgeted, ₹#{spent} spent (#{pct}%)"
      end.join("\n")
    end

    def formatted_investments
      investments = @user.investments.active.map { |i| "- #{i.name} (#{i.asset_class}): Invested ₹#{i.invested_amount}, Current ₹#{i.current_value}, P&L #{i.pnl_percentage}%" }
      investments.any? ? investments.join("\n") : "- No active investments"
    end

    def formatted_incomes(incomes)
      return "- No income entries for this month" if incomes.empty?
      incomes.map { |i| "- #{i.source}: ₹#{i.amount} (#{i.income_type.presence || 'salary'}, #{i.is_received ? 'Received' : 'Pending'})" }.join("\n")
    end

    def formatted_employments
      emps = @user.employments.by_recency
      return "- No employment records" if emps.empty?
      emps.map { |e| "- #{e.employer_name}: #{e.designation || 'N/A'} (#{e.start_date} — #{e.end_date || 'Present'})#{e.is_current ? ' [Current]' : ''}" }.join("\n")
    end

    def formatted_debt_clearance
      capital = SettlementCapitalService.new(@user).call
      accounts = @user.debt_accounts.open
      settlement_total = accounts.settlement.sum(:current_balance_paise) / 100.0
      protected_total = accounts.serviced.sum(:current_balance_paise) / 100.0

      <<~DEBT.strip
        - Protected Debt: ₹#{'%.2f' % protected_total} across #{accounts.serviced.count} accounts (serviced normally)
        - Settlement Debt: ₹#{'%.2f' % settlement_total} across #{accounts.settlement.count} accounts
        - Settlement Fund Available: ₹#{'%.2f' % capital[:current_settlement_fund]}
        - Monthly Surplus: ₹#{'%.2f' % capital[:available_monthly_surplus]} (allocation to settlements: ₹#{'%.2f' % capital[:settlement_allocation]})
      DEBT
    rescue StandardError
      "- Debt clearance data unavailable"
    end

    def formatted_settlement_pipeline
      entries = DebtQueueRanker.new(@user).call
      return "- No open settlement cases" if entries.empty?

      entries.map do |e|
        "- Case ##{e.settlement_case.id} #{e.debt_account.name} (#{e.debt_account.lender}): claim ₹#{e.debt_account.current_balance}, stage #{e.stage}, score #{e.score}, estimated total ₹#{e.estimated_total_paise / 100.0}, funding #{e.funding_progress}%#{e.eligible ? ' [ELIGIBLE]' : ''}"
      end.join("\n")
    rescue StandardError
      "- Settlement pipeline unavailable"
    end
  end
end
