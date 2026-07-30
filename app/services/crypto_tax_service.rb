class CryptoTaxService
  TDS_RATE_194S = 0.01
  TDS_THRESHOLD_FY = 50_000
  TAX_RATE_115BBH = 0.30

  def initialize(user, financial_year:)
    @user = user
    @financial_year = financial_year
    @fy_start = Date.new(financial_year - 1, 4, 1)
    @fy_end = Date.new(financial_year, 3, 31)
  end

  def total_crypto_pnl
    investments = @user.investments
      .where(asset_class: "crypto", purchase_date: @fy_start..@fy_end)
    investments.sum(:realized_pnl).to_d + investments.sum(:unrealized_pnl).to_d
  end

  def taxable_amount
    pnl = total_crypto_pnl
    pnl.positive? ? pnl : 0.0
  end

  def tax_due
    taxable_amount * TAX_RATE_115BBH
  end

  def tds_deducted
    @user.tax_deductions
      .where(deduction_type: "tds", section: "194S")
      .where(deduction_date: @fy_start..@fy_end)
      .sum(:amount).to_d
  end

  def tds_shortfall
    [tax_due - tds_deducted, 0].max
  end

  def tds_required?
    total_sale_value = @user.trades
      .for_broker("coindcx")
      .for_period(@fy_start, @fy_end)
      .sell
      .sum("traded_quantity * traded_price").to_d

    total_sale_value > TDS_THRESHOLD_FY
  end

  def tds_to_deduct_on_sale(sale_value)
    return 0 unless tds_required?
    (sale_value * TDS_RATE_194S).round(2)
  end
end
