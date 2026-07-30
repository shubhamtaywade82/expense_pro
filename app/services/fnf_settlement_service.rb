class FnfSettlementService
  def initialize(employment)
    @employment = employment
  end

  def call(fnf_date: nil, gratuity_amount: 0, leave_encashment: 0, bonus_amount: 0, deductions: 0)
    return { errors: ["Employment already settled"] } if @employment.fnf_settled_at.present?

    fnf_date = Date.parse(fnf_date) if fnf_date.is_a?(String)
    fnf_date ||= Date.current

    components = @employment.salary_components
    computed_gratuity = gratuity_amount.to_d
    if computed_gratuity.zero? && (basic = components.find_by(component_type: "basic"))
      computed_gratuity = (basic.monthly_amount.to_d * 15 / 26 * years_of_service).round(2)
    end

    total = computed_gratuity + leave_encashment.to_d + bonus_amount.to_d - deductions.to_d

    @employment.update!(is_current: false, end_date: fnf_date, fnf_settled_at: Time.current)

    @employment.incomes.create!(
      user: @employment.user,
      source: "FNF Settlement - #{@employment.employer_name}",
      amount: total,
      income_date: fnf_date,
      income_type: "fnf",
      is_recurring: false,
      frequency: "one_time",
      is_received: true,
      notes: "Gratuity: #{computed_gratuity}, Leave: #{leave_encashment}, Bonus: #{bonus_amount}, Deductions: #{deductions}"
    )

    {
      fnf_date: fnf_date,
      gratuity: computed_gratuity.to_s,
      leave_encashment: leave_encashment.to_s,
      bonus: bonus_amount.to_s,
      deductions: deductions.to_s,
      net_settlement: total.to_s,
      income_id: @employment.incomes.last.id
    }
  end

  private

  def years_of_service
    start_date = @employment.start_date
    end_date = @employment.end_date || Date.current
    ((end_date - start_date).to_i / 365.0).round(1)
  end
end
