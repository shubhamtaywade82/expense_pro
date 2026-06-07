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
    incomes = IncomeProjectionService.new(user, month, year).call
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
    incomes = user.incomes.where(income_date: period)
    emis = user.emi_payments.where(due_date: period)
    bills = user.monthly_bills.active

    total_expense = expenses.sum(:amount)
    total_income = (0..11).sum do |offset|
      m_date = fy_start.advance(months: offset)
      IncomeProjectionService.new(user, m_date.month, m_date.year).call.sum(&:amount)
    end
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
      monthlyData: monthly_breakdown(fy_start, expenses, incomes, bills, emis),
      categoryYearly: category_expenses(expenses),
      loanSummary: loan_summary
    }
  end

  private

  attr_reader :user

  def category_expenses(expenses)
    grouped = expenses.joins(:category).group("categories.id", "categories.name", "categories.color")

    sums = grouped.sum(:amount)
    counts = grouped.count

    sums
      .map { |(_id, name, color), total| { categoryName: name, categoryColor: color, total: total.to_s, count: counts[[ _id, name, color ]] } }
      .sort_by { |row| -row[:total].to_f }
  end

  def daily_expenses(expenses, period)
    totals = expenses.group(:expense_date).sum(:amount)
    period.map { |date| { date: date, total: (totals[date] || 0).to_s } }
  end

  def monthly_breakdown(fy_start, expenses, incomes, bills, emis)
    bills_total = bills.sum(:amount)

    expenses_by_month = expenses.group("to_char(expense_date, 'YYYY-MM')").sum(:amount)
    emis_by_month = emis.group("to_char(due_date, 'YYYY-MM')").sum(:amount)

    (0..11).map do |offset|
      m_date = fy_start.advance(months: offset)
      key = m_date.strftime("%Y-%m")
      incomes = IncomeProjectionService.new(user, m_date.month, m_date.year).call
      {
        month: key,
        expenses: (expenses_by_month[key] || 0).to_s,
        income: incomes.sum(&:amount).to_s,
        bills: bills_total.to_s,
        emis: (emis_by_month[key] || 0).to_s
      }
    end
  end

  def loan_summary
    user.loans.includes(:emi_payments).map do |loan|
      paid = loan.emi_payments.count(&:is_paid)
      {
        name: loan.name,
        isActive: paid < loan.tenure_months,
        principalAmount: loan.principal_amount.to_s,
        emiAmount: loan.emi_amount.to_s,
        outstandingPrincipal: loan.outstanding_principal.to_s,
        paidEmiCount: paid,
        remainingEmiCount: loan.tenure_months - paid
      }
    end
  end
end
