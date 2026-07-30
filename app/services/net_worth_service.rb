class NetWorthService
  def initialize(user)
    @user = user
  end

  def calculate
    assets = compute_assets
    liabilities = compute_liabilities
    total_assets = assets.values.sum
    total_liabilities = liabilities[:total]

    {
      assets: assets,
      liabilities: liabilities,
      net_worth: (total_assets - total_liabilities).round(2),
      liquid_assets: assets[:liquid_cash],
      emergency_fund_months: emergency_fund_coverage(assets[:liquid_cash]),
      debt_to_asset_ratio: total_liabilities > 0 && total_assets > 0 ?
        (total_liabilities / total_assets * 100).round(1) : 0,
      trend: net_worth_trend
    }
  end

  private

  def compute_assets
    investments_total = @user.investments.where(status: "active").sum do |i|
      i.current_value.to_f
    end
    realized_investments = @user.investments.where(status: "realized").sum(:realized_pnl).to_f

    # EPF/PPF/NPS: stored as investments with those asset classes
    epf = @user.investments.where(asset_class: "fixed_income").sum do |i|
      i.name.match?(/(epf|ppf|nps)/i) ? i.current_value.to_f : 0
    end

    {
      liquid_cash: current_account_balance,
      investments: investments_total,
      realized_investment_pnl: realized_investments,
      retirement_accounts: epf,
      total: investments_total + realized_investments + current_account_balance + epf
    }
  end

  def compute_liabilities
    loans = @user.loans.includes(:emi_payments)

    loan_details = loans.map do |l|
      outstanding = l.outstanding_principal.to_f
      next if outstanding <= 0

      {
        id: l.id,
        name: l.name,
        loan_type: l.loan_type,
        outstanding: outstanding,
        emi: l.emi_amount.to_f,
        interest_rate: l.interest_rate.to_f
      }
    end.compact

    total_outstanding = loan_details.sum { |l| l[:outstanding] }

    {
      loans: loan_details,
      total: total_outstanding
    }
  end

  def current_account_balance
    # Best estimate from income - expenses - bills - emis (life-to-date)
    total_income = @user.incomes.sum(:amount).to_f
    total_expenses = @user.expenses.sum(:amount).to_f
    total_bills_paid = @user.monthly_bills.where(is_paid: true).sum(:amount).to_f
    total_emis_paid = @user.emi_payments.where(is_paid: true).sum(:amount).to_f

    [total_income - total_expenses - total_bills_paid - total_emis_paid, 0].max
  end

  def emergency_fund_coverage(liquid)
    monthly_expenses = @user.expenses
      .where(expense_date: 3.months.ago..Date.current)
      .average(:amount).to_f || 0

    monthly_expenses > 0 ? (liquid / monthly_expenses).round(1) : 0
  end

  def net_worth_trend
    # Simplified: compute current snapshot only
    # Full trend requires NetWorthSnapshot model
    nil
  end
end
