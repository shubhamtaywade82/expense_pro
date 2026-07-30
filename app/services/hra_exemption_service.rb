class HraExemptionService
  def initialize(employment)
    @employment = employment
    @salary_components = @employment.salary_components.index_by(&:component_type)
  end

  def call
    hra = @salary_components["hra"]
    basic = @salary_components["basic"]
    return { hra_exempt: 0, hra_received: 0, eligible_exemption: 0, rent_paid: 0 } unless hra && basic

    rent_paid = hra.hra_rent_paid.to_d
    return { hra_exempt: 0, hra_received: 0, eligible_exemption: 0, rent_paid: 0 } if rent_paid.zero?

    actual_hra_received = hra.monthly_amount.to_d * 12
    actual_rent_minus_10pc_basic = (rent_paid * 12) - (basic.monthly_amount.to_d * 12 * 0.1)
    hra_exempt = [actual_hra_received, actual_rent_minus_10pc_basic, half_of_basic].min
    hra_exempt = [hra_exempt, 0].max

    {
      hra_received: actual_hra_received.to_s,
      hra_exempt: hra_exempt.to_s,
      eligible_exemption: actual_rent_minus_10pc_basic.to_s,
      rent_paid: (rent_paid * 12).to_s
    }
  end

  private

  def half_of_basic
    metro = @employment.pan_of_employer.present?
    metro ? (basic.monthly_amount.to_d * 12 * 0.5) : (basic.monthly_amount.to_d * 12 * 0.4)
  end
end
