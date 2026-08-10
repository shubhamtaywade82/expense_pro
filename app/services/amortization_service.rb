class AmortizationService
  def initialize(loan_account)
    @loan = loan_account
  end

  def generate_schedule!
    recalculate_multistage!
  end

  def recalculate_multistage!(rate_revisions: nil, disbursements: nil)
    @loan.update!(rate_revisions: rate_revisions) if rate_revisions.present?
    @loan.update!(disbursements: disbursements) if disbursements.present?

    paid_map = existing_paid_map
    @loan.emi_schedules.destroy_all

    build_schedule!(paid_map)
    update_loan_aggregates!
  end

  def import_schedule!(rows)
    @loan.emi_schedules.destroy_all

    rows.each_with_index do |row, idx|
      @loan.emi_schedules.create!(
        installment_number: row[:installment_number] || (idx + 1),
        due_date: row[:due_date],
        opening_balance: row[:opening_balance].to_f.round(2),
        emi_amount: row[:emi_amount].to_f.round(2),
        principal_component: row[:principal_component].to_f.round(2),
        interest_component: row[:interest_component].to_f.round(2),
        closing_balance: row[:closing_balance].to_f.round(2),
        status: row[:status].presence || "pending",
        paid_on: row[:paid_on]
      )
    end

    update_loan_aggregates!
  end

  def update_installment!(schedule_id, attrs)
    schedule = @loan.emi_schedules.find(schedule_id)
    schedule.update!(attrs)
    update_loan_aggregates!
    schedule
  end

  private

  def existing_paid_map
    @loan.emi_schedules.where(status: "paid").index_by(&:installment_number).transform_values do |s|
      { status: s.status, paid_on: s.paid_on }
    end
  end

  def build_schedule!(paid_map)
    start_date = @loan.start_date || Date.current
    revisions = sorted_revisions
    disb_list = sorted_disbursements
    tenure = @loan.tenure_months.to_i > 0 ? @loan.tenure_months.to_i : 120
    current_emi = @loan.emi_amount.to_f > 0 ? @loan.emi_amount.to_f : nil

    balance = initial_balance(disb_list)
    max_months = [tenure * 2, 480].max

    (1..max_months).each do |inst_num|
      break if balance <= 0 && inst_num > 1

      due_date = start_date + inst_num.months
      balance = apply_tranches(balance, disb_list, due_date)
      current_rate = active_rate(revisions, due_date)
      monthly_rate = (current_rate / 100.0) / 12.0

      current_emi = compute_monthly_emi(balance, monthly_rate, tenure - inst_num + 1, current_emi, revisions, due_date)
      installment = calculate_installment(balance, monthly_rate, current_emi)

      save_schedule_row(inst_num, due_date, balance, installment, paid_map[inst_num])
      balance = installment[:closing_balance]
    end
  end

  def initial_balance(disb_list)
    if disb_list.any?
      disb_list.select { |d| d[:disbursed_on] <= (@loan.start_date || Date.current) }.sum { |d| d[:amount].to_f }
    else
      @loan.principal_amount.to_f
    end
  end

  def apply_tranches(balance, disb_list, due_date)
    return balance if disb_list.empty?

    # Add tranches that disbursed between previous month and this due_date
    prev_date = due_date - 1.month
    new_tranches = disb_list.select do |d|
      d_date = d[:disbursed_on].is_a?(Date) ? d[:disbursed_on] : Date.parse(d[:disbursed_on].to_s)
      d_date > prev_date && d_date <= due_date
    end
    balance + new_tranches.sum { |d| d[:amount].to_f }
  end

  def sorted_revisions
    return [] unless @loan.rate_revisions.is_a?(Array)
    @loan.rate_revisions.map(&:symbolize_keys).sort_by { |r| r[:effective_date].to_s }
  end

  def sorted_disbursements
    return [] unless @loan.disbursements.is_a?(Array)
    @loan.disbursements.map(&:symbolize_keys).sort_by { |d| d[:disbursed_on].to_s }
  end

  def active_rate(revisions, due_date)
    effective = revisions.reverse.find do |r|
      r_date = r[:effective_date].is_a?(Date) ? r[:effective_date] : Date.parse(r[:effective_date].to_s)
      r_date <= due_date
    end
    effective ? effective[:interest_rate].to_f : @loan.interest_rate.to_f
  end

  def compute_monthly_emi(balance, monthly_rate, remaining_tenure, current_emi, revisions, due_date)
    needs_recalc = current_emi.nil? || revision_triggers_emi_change?(revisions, due_date)
    return current_emi unless needs_recalc

    calculate_emi(balance, monthly_rate, [remaining_tenure, 1].max)
  end

  def revision_triggers_emi_change?(revisions, due_date)
    rev = revisions.find do |r|
      r_date = r[:effective_date].is_a?(Date) ? r[:effective_date] : Date.parse(r[:effective_date].to_s)
      r_date > (due_date - 1.month) && r_date <= due_date
    end
    rev && rev[:strategy] == "adjust_emi"
  end

  def calculate_emi(principal, monthly_rate, tenure)
    return (principal / tenure).round(2) if monthly_rate <= 0
    factor = (1 + monthly_rate)**tenure
    (principal * monthly_rate * factor / (factor - 1)).round(2)
  end

  def calculate_installment(balance, monthly_rate, emi)
    interest = (balance * monthly_rate).round(2)
    principal_part = (emi - interest).round(2)

    if balance <= principal_part || principal_part <= 0
      principal_part = [balance, 0].max
      emi = (principal_part + interest).round(2)
      closing = 0.0
    else
      closing = (balance - principal_part).round(2)
    end

    { emi: emi, principal: principal_part, interest: interest, closing_balance: closing }
  end

  def save_schedule_row(inst_num, due_date, opening_balance, installment, paid_info)
    @loan.emi_schedules.create!(
      installment_number: inst_num,
      due_date: due_date,
      opening_balance: opening_balance.round(2),
      emi_amount: installment[:emi],
      principal_component: installment[:principal],
      interest_component: installment[:interest],
      closing_balance: installment[:closing_balance],
      status: paid_info ? paid_info[:status] : "pending",
      paid_on: paid_info ? paid_info[:paid_on] : nil
    )
  end

  def update_loan_aggregates!
    paid_principal = @loan.emi_schedules.where(status: "paid").sum(:principal_component)
    outstanding = [@loan.principal_amount.to_d - paid_principal, 0].max
    @loan.update_columns(outstanding_principal: outstanding)
  end
end
