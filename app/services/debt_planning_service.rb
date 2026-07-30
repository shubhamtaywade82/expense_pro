class DebtPlanningService
  def initialize(user)
    @user = user
  end

  def debt_summary
    loans = @user.loans.includes(:emi_payments).select { |l| l.outstanding_principal > 0 }

    {
      total_outstanding: loans.sum(&:outstanding_principal).to_f,
      secured_debt: loans.select { |l| %w[home car education gold].include?(l.loan_type) }.sum(&:outstanding_principal).to_f,
      unsecured_debt: loans.select { |l| %w[personal business other].include?(l.loan_type) }.sum(&:outstanding_principal).to_f,
      debt_to_income_ratio: calculate_dti(loans),
      loans: loans.map { |l| loan_detail(l) },
      monthly_surplus: calculate_surplus
    }
  end

  def simulate_payoff(strategy:, extra_monthly: 0)
    loans = @user.loans.includes(:emi_payments)
      .select { |l| l.outstanding_principal > 0 }
    return { error: "No active loans" } if loans.empty?

    ordered = case strategy.to_s
              when "avalanche"
                loans.sort_by { |l| [-l.interest_rate.to_f, l.outstanding_principal.to_f] }
              when "snowball"
                loans.sort_by { |l| [l.outstanding_principal.to_f, -l.interest_rate.to_f] }
              else
                loans.sort_by { |l| [-l.interest_rate.to_f, l.outstanding_principal.to_f] }
              end

    monthly_surplus = calculate_surplus + extra_monthly
    balances = {}
    min_payments = {}
    rates = {}

    ordered.each do |loan|
      balances[loan.id] = loan.outstanding_principal.to_f
      min_payments[loan.id] = loan.emi_amount.to_f
      rates[loan.id] = loan.interest_rate.to_f
    end

    timeline = []
    month = 0
    total_interest_paid = 0.0
    monthly_rate = rates.values.first.to_f / 12.0 / 100.0

    while balances.values.any? { |b| b > 0 } && month < 600
      month += 1
      extra = monthly_surplus

      ordered.each do |loan|
        bal = balances[loan.id]
        next if bal <= 0

        rate = rates[loan.id] / 12.0 / 100.0
        interest = (bal * rate).round(2)
        min_pmt = [min_payments[loan.id], bal + interest].min
        total_pmt = min_pmt + extra

        if total_pmt >= bal + interest
          principal_paid = bal
          extra = total_pmt - bal - interest
        else
          principal_paid = total_pmt - interest
          extra = 0
        end

        principal_paid = [principal_paid, 0].max
        balances[loan.id] = (bal - principal_paid).round(2)
        balances[loan.id] = 0 if balances[loan.id] < 0.01
        total_interest_paid += interest
      end

      timeline << { month: month, balances: balances.transform_values { |v| v.round(2) } }
    end

    {
      strategy: strategy,
      total_months: month,
      projected_payoff_date: (Date.current + month.months).to_s,
      total_interest_paid: total_interest_paid.round(2),
      timeline: timeline
    }
  end

  private

  def calculate_dti(loans)
    monthly_income = @user.incomes
      .where(income_date: Date.current.beginning_of_month..Date.current.end_of_month)
      .sum(:amount).to_f
    return 0 if monthly_income.zero?

    total_obligations = loans.sum { |l| l.emi_amount.to_f }
    (total_obligations / monthly_income * 100).round(1)
  end

  def calculate_surplus
    income = @user.incomes
      .where(income_date: Date.current.beginning_of_month..Date.current.end_of_month)
      .sum(:amount).to_f
    essentials = @user.expenses
      .where(expense_date: Date.current.beginning_of_month..Date.current.end_of_month)
      .sum(:amount).to_f
    min_emis = @user.loans.includes(:emi_payments)
      .select { |l| l.outstanding_principal > 0 }
      .sum { |l| l.emi_amount.to_f }

    [income - essentials - min_emis, 0].max
  end

  def loan_detail(loan)
    {
      id: loan.id,
      name: loan.name,
      type: loan.loan_type,
      principal: loan.principal_amount.to_f,
      outstanding: loan.outstanding_principal.to_f,
      emi: loan.emi_amount.to_f,
      rate: loan.interest_rate.to_f,
      tenure: loan.tenure_months,
      remaining_emis: loan.emi_payments.where(is_paid: false).count,
      paid_emis: loan.emi_payments.where(is_paid: true).count
    }
  end
end
