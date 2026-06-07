class DashboardService
  def initialize(user, month:, year:)
    @user = user
    @month = month.to_i
    @year = year.to_i
    @period = Date.new(@year, @month, 1)..Date.new(@year, @month, -1)
  end

  def overview
    {
      expenses: expense_summary,
      income: income_summary,
      bills: bill_summary,
      emis: emi_summary,
      loans: loan_summary,
      overall: overall_summary,
      monthlyTrend: monthly_trend,
      categoryBreakdown: category_breakdown,
      recentExpenses: recent_expenses
    }
  end

  private

  attr_reader :user, :month, :year, :period

  def overall_summary
    first_record = user.incomes.order(:income_date).first&.income_date || Date.current
    all_incomes = IncomeProjectionService.new(user, first_record, Date.current).call
    
    total_income = all_incomes.sum(&:amount)
    total_expense = user.expenses.sum(:amount)
    total_emi_paid = user.emi_payments.where(is_paid: true).sum(:amount)
    
    {
      totalIncome: total_income.to_s,
      totalExpense: total_expense.to_s,
      totalEmiPaid: total_emi_paid.to_s,
      netBalance: (total_income - total_expense - total_emi_paid).to_s
    }
  end

  def expense_summary
    scope = user.expenses.where(expense_date: period)
    { total: scope.sum(:amount).to_s, count: scope.count }
  end

  def income_summary
    incomes = IncomeProjectionService.new(user, period.first, period.last).call
    { 
      total: incomes.sum(&:amount).to_s, 
      count: incomes.count,
      received: incomes.count(&:is_received),
      expected: incomes.count { |inc| !inc.is_received }
    }
  end

  def bill_summary
    scope = user.monthly_bills.active
    stats = scope.select("SUM(amount) AS total_amount, COUNT(CASE WHEN is_paid = true THEN 1 END) AS paid_count, COUNT(CASE WHEN is_paid = false THEN 1 END) AS unpaid_count").take
    {
      total: (stats.total_amount || 0).to_s,
      paid: stats.paid_count || 0,
      unpaid: stats.unpaid_count || 0
    }
  end

  def emi_summary
    scope = user.emi_payments.where(due_date: period)
    stats = scope.select("SUM(amount) AS total_amount, COUNT(CASE WHEN is_paid = true THEN 1 END) AS paid_count, COUNT(*) AS total_count").take
    {
      total: (stats.total_amount || 0).to_s,
      paid: stats.paid_count || 0,
      totalCount: stats.total_count || 0
    }
  end

  def loan_summary
    loans = user.loans.includes(:emi_payments).to_a
    {
      activeCount: loans.size,
      outstandingTotal: loans.sum(&:outstanding_principal).to_s,
      totalEMI: loans.sum(&:emi_amount).to_s
    }
  end

  def monthly_trend(months_back: 6)
    range_start = period.first.advance(months: -(months_back - 1)).beginning_of_month
    range_end = period.last

    expenses_by_month = user.expenses
      .where(expense_date: range_start..range_end)
      .group("to_char(expense_date, 'YYYY-MM')")
      .sum(:amount)

    all_incomes = IncomeProjectionService.new(user, range_start, range_end).call
    income_by_month = all_incomes.group_by { |i| i.income_date.strftime("%Y-%m") }
                                .transform_values { |incs| incs.sum(&:amount) }

    (0...months_back).map do |offset|
      key = range_start.advance(months: offset).strftime("%Y-%m")
      {
        month: key,
        expenses: (expenses_by_month[key] || 0).to_s,
        income: (income_by_month[key] || 0).to_s
      }
    end
  end

  def category_breakdown(limit: 6)
    user.expenses
      .joins(:category)
      .where(expense_date: period)
      .group("categories.id", "categories.name", "categories.color")
      .order(Arel.sql("SUM(expenses.amount) DESC"))
      .limit(limit)
      .sum(:amount)
      .map do |(_id, name, color), total|
        { categoryName: name, categoryColor: color, total: total.to_s }
      end
  end

  def recent_expenses(limit: 5)
    user.expenses.includes(:category).recent_first.limit(limit).map do |expense|
      {
        id: expense.id,
        description: expense.description,
        amount: expense.amount.to_s,
        expenseDate: expense.expense_date,
        categoryName: expense.category.name,
        categoryColor: expense.category.color
      }
    end
  end
end
