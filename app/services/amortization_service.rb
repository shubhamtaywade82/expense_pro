class AmortizationService
  def initialize(loan_account)
    @loan = loan_account
  end

  def generate_schedule!
    @loan.emi_schedules.destroy_all

    principal = @loan.principal_amount.to_f
    monthly_rate = (@loan.interest_rate.to_f / 100.0) / 12.0
    tenure = @loan.tenure_months

    # Calculate exact EMI if not provided correctly, but let's assume it is calculated standard
    if monthly_rate > 0
      emi = principal * monthly_rate * ((1 + monthly_rate)**tenure) / (((1 + monthly_rate)**tenure) - 1)
    else
      emi = principal / tenure
    end

    @loan.update!(emi_amount: emi) if @loan.emi_amount.nil? || @loan.emi_amount == 0

    balance = principal
    current_date = @loan.start_date || Date.today

    tenure.times do |i|
      break if balance <= 0

      interest = balance * monthly_rate
      principal_component = emi - interest
      
      # Adjust last installment
      if balance < principal_component || i == tenure - 1
        principal_component = balance
        emi = principal_component + interest
      end

      closing_balance = balance - principal_component

      @loan.emi_schedules.create!(
        due_date: current_date + (i + 1).months,
        installment_number: i + 1,
        opening_balance: balance,
        emi_amount: emi,
        principal_component: principal_component,
        interest_component: interest,
        closing_balance: closing_balance,
        status: "pending"
      )

      balance = closing_balance
    end
  end

  def apply_prepayment!(amount, date, impact = "reduce_tenure")
    @loan.prepayments.create!(amount: amount, date: date, impact: impact)
    
    # Recalculate schedule from the date of prepayment
    # For now, we'll implement a full rebuild based on current outstanding
    # This is a simplified version of the logic
  end
end
