class DashboardService
  def initialize(user, month:, year:)
    @user = user
    @month = month.to_i
    @year = year.to_i
    @period = Date.new(@year, @month, 1)..Date.new(@year, @month, -1)
  end

  def overview
    investments = investment_summary
    tax_est = tax_estimate(investments[:total_pnl].to_f)

    nw = NetWorthService.new(@user).calculate

    {
      expenses: expense_summary,
      income: income_summary,
      bills: bill_summary,
      emis: emi_summary,
      loans: loan_summary,
      investments: investments,
      taxEstimate: tax_est,
      overall: overall_summary,
      monthlyTrend: monthly_trend,
      categoryBreakdown: category_breakdown,
      recentExpenses: recent_expenses,
      netWorth: {
        netWorth: nw[:net_worth],
        emergencyFundMonths: nw[:emergency_fund_months],
        debtToAssetRatio: nw[:debt_to_asset_ratio]
      }
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
    loans = user.loans.to_a
    total_principal = loans.sum { |l| l.principal_amount.to_d }
    total_paid_principal = user.emi_payments.where(loan_id: loans.map(&:id), is_paid: true).sum(:principal_amount)

    {
      activeCount: loans.size,
      outstandingTotal: (total_principal - total_paid_principal).to_s,
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

  def investment_summary
    fy_start = month >= 4 ? Date.new(year, 4, 1) : Date.new(year - 1, 4, 1)
    fy_end = fy_start + 1.year - 1.day

    investments = user.investments
      .where(purchase_date: fy_start..fy_end)
      .or(user.investments.where(status: "realized", sell_date: fy_start..fy_end))

    total_invested = investments.sum(:invested_amount).to_f
    current_value = investments.sum { |i| i.status == "realized" ? i.sell_price.to_f * i.quantity.to_i : i.current_price.to_f * i.quantity.to_i }
    total_pnl = investments.sum(&:total_pnl).to_f

    {
      totalInvested: total_invested.to_s,
      currentValue: current_value.to_s,
      totalPnl: total_pnl.to_s,
      count: investments.size,
      assetClasses: investments.group_by(&:asset_class).transform_values(&:size)
    }
  end

  def tax_estimate(trading_pnl)
    fy_start = month >= 4 ? Date.new(year, 4, 1) : Date.new(year - 1, 4, 1)
    fy_end = fy_start + 1.year - 1.day

    incomes = IncomeProjectionService.new(user, fy_start, fy_end).call
    gross_income = incomes.sum { |i| (i.gross_amount || i.amount).to_f }
    tds_paid = incomes.sum { |i| i.tax_deducted.to_f }

    taxable_income = [ gross_income - 75_000, 0 ].max + [ trading_pnl, 0 ].max

    tax = 0.0
    tax += (800_000 - 400_000) * 0.05 if taxable_income > 400_000
    tax += ([ taxable_income, 1_200_000 ].min - 800_000) * 0.10 if taxable_income > 800_000
    tax += ([ taxable_income, 1_600_000 ].min - 1_200_000) * 0.15 if taxable_income > 1_200_000
    tax += ([ taxable_income, 2_000_000 ].min - 1_600_000) * 0.20 if taxable_income > 1_600_000
    tax += ([ taxable_income, 2_400_000 ].min - 2_000_000) * 0.25 if taxable_income > 2_000_000
    tax += (taxable_income - 2_400_000) * 0.30 if taxable_income > 2_400_000

    if taxable_income <= 1_200_000
      total_tax = 0.0
    else
      cess = (tax * 0.04).round(2)
      total_tax = (tax + cess).round(2)
    end

    tax_payable = [ total_tax - tds_paid, 0 ].max.round(2)

    {
      grossIncome: gross_income,
      estimatedTax: total_tax,
      tdsPaid: tds_paid,
      taxPayable: tax_payable,
      effectiveRate: gross_income > 0 ? ((total_tax / gross_income) * 100).round(1) : 0
    }
  end
end
