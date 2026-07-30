class ReportService
  def initialize(user)
    @user = user
  end

  def monthly(month:, year:)
    period = Date.new(year, month, 1)..Date.new(year, month, -1)
    expenses = user.expenses.where(expense_date: period)
    bills = user.monthly_bills.active
    emis = user.emi_payments.includes(:loan).where(due_date: period)

    total_expense = expenses.sum(:amount)
    incomes = IncomeProjectionService.new(user, period.first, period.last).call
    total_income = incomes.sum(&:amount)
    total_bills = bills.sum(:amount)
    total_emi = emis.sum(:amount)

    {
      summary: {
        totalExpense: total_expense.to_s,
        totalIncome: total_income.to_s,
        totalBills: total_bills.to_s,
        totalEMI: total_emi.to_s,
        netSavings: (total_income - total_expense - total_bills - total_emi).to_s
      },
      categoryExpenses: category_expenses(expenses),
      incomeByType: income_by_type(incomes),
      dailyExpenses: daily_expenses(expenses, period),
      billsSummary: bills.map { |bill| { name: bill.name, amount: bill.amount.to_s, isPaid: bill.is_paid } },
      emiSummary: emis.map { |emi| { loanName: emi.loan.name, emiAmount: emi.amount.to_s, isPaid: emi.is_paid } }
    }
  end

  def financial_year(year:)
    fy_start = Date.new(year, 4, 1)
    fy_end = Date.new(year + 1, 3, 31)
    period = fy_start..fy_end

    expenses = user.expenses.where(expense_date: period)
    emis = user.emi_payments.where(due_date: period)
    bills = user.monthly_bills.active

    total_expense = expenses.sum(:amount)
    all_incomes = IncomeProjectionService.new(user, fy_start, fy_end).call
    total_income = all_incomes.sum(&:amount)
    total_bills_yearly = bills.sum(:amount) * 12
    total_emi = emis.sum(:amount)

    {
      summary: {
        totalExpense: total_expense.to_s,
        totalIncome: total_income.to_s,
        totalBills: total_bills_yearly.to_s,
        totalEMI: total_emi.to_s,
        netSavings: (total_income - total_expense - total_bills_yearly - total_emi).to_s
      },
      monthlyData: monthly_breakdown(fy_start, expenses, all_incomes, bills, emis),
      incomeByType: income_by_type(all_incomes),
      categoryYearly: category_expenses(expenses),
      loanSummary: loan_summary
    }
  end

  private

  attr_reader :user

  def category_expenses(expenses)
    expenses.joins(:category)
      .group("categories.id", "categories.name", "categories.color")
      .select("categories.name, categories.color, SUM(expenses.amount) AS total_amount, COUNT(expenses.id) AS expense_count")
      .map do |row|
        {
          categoryName: row.name,
          categoryColor: row.color,
          total: row.total_amount.to_s,
          count: row.expense_count
        }
      end
      .sort_by { |row| -row[:total].to_f }
  end

  def daily_expenses(expenses, period)
    totals = expenses.group(:expense_date).sum(:amount)
    period.map { |date| { date: date, total: (totals[date] || 0).to_s } }
  end

  def income_by_type(incomes)
    incomes.group_by { |i| i.income_type.presence || "salary" }
           .transform_values { |incs| incs.sum(&:amount).to_f }
           .sort_by { |_, v| -v }
           .to_h
  end

  def monthly_breakdown(fy_start, expenses, all_incomes, bills, emis)
    bills_total = bills.sum(:amount)

    expenses_by_month = expenses.group("to_char(expense_date, 'YYYY-MM')").sum(:amount)
    emis_by_month = emis.group("to_char(due_date, 'YYYY-MM')").sum(:amount)
    income_by_month = all_incomes.group_by { |i| i.income_date.strftime("%Y-%m") }
                                .transform_values { |incs| incs.sum(&:amount) }

    (0..11).map do |offset|
      key = fy_start.advance(months: offset).strftime("%Y-%m")
      {
        month: key,
        expenses: (expenses_by_month[key] || 0).to_s,
        income: (income_by_month[key] || 0).to_s,
        bills: bills_total.to_s,
        emis: (emis_by_month[key] || 0).to_s
      }
    end
  end

  def loan_summary
    loans = user.loans.to_a
    aggregates = Loan.batch_aggregates(loans)

    loans.map do |loan|
      agg = aggregates[loan]
      {
        name: loan.name,
        isActive: agg[:paid_count] < loan.tenure_months,
        principalAmount: loan.principal_amount.to_s,
        emiAmount: loan.emi_amount.to_s,
        outstandingPrincipal: agg[:outstanding_principal].to_s,
        paidEmiCount: agg[:paid_count],
        remainingEmiCount: loan.tenure_months - agg[:paid_count]
      }
    end
  end
end
