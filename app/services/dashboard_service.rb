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
      monthlyTrend: monthly_trend,
      categoryBreakdown: category_breakdown,
      recentExpenses: recent_expenses
    }
  end

  private

  attr_reader :user, :month, :year, :period

  def expense_summary
    scope = user.expenses.where(expense_date: period)
    { total: scope.sum(:amount).to_s, count: scope.count }
  end

  def income_summary
    scope = user.incomes.where(income_date: period)
    { total: scope.sum(:amount).to_s, count: scope.count }
  end

  def bill_summary
    scope = user.monthly_bills.active
    {
      total: scope.sum(:amount).to_s,
      paid: scope.where(is_paid: true).count,
      unpaid: scope.where(is_paid: false).count
    }
  end

  def emi_summary
    scope = user.emi_payments.where(due_date: period)
    {
      total: scope.sum(:amount).to_s,
      paid: scope.where(is_paid: true).count,
      totalCount: scope.count
    }
  end

  def loan_summary
    loans = user.loans.includes(:emi_payments)
    {
      activeCount: loans.count,
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

    income_by_month = user.incomes
      .where(income_date: range_start..range_end)
      .group("to_char(income_date, 'YYYY-MM')")
      .sum(:amount)

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
