class DocumentChecklistService
  # Persona-aware: only asks for documents the user actually needs
  def initialize(user, financial_year)
    @user = user
    @fy = financial_year
  end

  def status
    required = required_documents
    uploaded = @user.tax_documents.for_fy(@fy).distinct.pluck(:document_type)
    verified = @user.tax_documents.for_fy(@fy).where(status: :verified).distinct.pluck(:document_type)

    {
      financial_year: @fy,
      persona: detect_persona,
      total_required: required.size,
      total_uploaded: uploaded.size,
      total_verified: verified.size,
      completion_pct: required.empty? ? 100 : ((verified & required).size * 100.0 / required.size).round,
      missing_required: required - uploaded,
      pending_verification: (uploaded - verified) & required,
      checklist: required.map do |doc_type|
        {
          document_type: doc_type,
          label: LABELS[doc_type],
          status: verified.include?(doc_type) ? :verified :
                  uploaded.include?(doc_type) ? :pending_verification : :missing,
          mandatory: MANDATORY.include?(doc_type),
          tip: TIPS[doc_type]
        }
      end
    }
  end

  private

  def required_documents
    base = %w[pan_card aadhaar_card form_26as ais_json]
    base += %w[form_16] if salaried?
    base += %w[rent_receipt rent_agreement] if salaried? && claims_hra?
    base += %w[home_loan_certificate] if has_home_loan?
    base += %w[health_insurance_80d] if claims_80d?
    base += %w[capital_gains_stmt trading_pnl_stmt] if trader?
    base += %w[crypto_statement] if crypto_trader?
    base += %w[bank_statement] if trader? || business?
    base += %w[pnl_statement gst_return] if business?
    base += %w[advance_tax_challan] if pays_advance_tax?
    base.uniq
  end

  def detect_persona
    personas = []
    personas << :salaried if salaried?
    personas << :trader if trader?
    personas << :business if business?
    personas.empty? ? [:individual] : personas
  end

  def salaried? = @user.incomes.for_fy(@fy).where(income_type: :salary).exists? || @user.incomes.for_fy(@fy).where(income_source: :salary).exists?
  def trader? = @user.trades.for_fy(@fy).where(broker_type: 'securities').exists? rescue false
  def crypto_trader? = @user.trades.for_fy(@fy).where(broker_type: 'crypto').exists? rescue false
  def business? = defined?(@user.businesses) && @user.businesses.exists?
  def has_home_loan? = defined?(@user.loan_accounts) && @user.loan_accounts.where(loan_type: :home_loan, status: :active).exists?
  def claims_hra? = defined?(@user.salary_structures) && @user.salary_structures.exists? # simplified since we don't have rent_amount
  def claims_80d? = true  # everyone should have health insurance
  def pays_advance_tax? = TaxCalculatorService.new(@user, @fy).call.dig(:advance_tax_required) rescue false

  LABELS = {
    "pan_card" => "PAN Card", "aadhaar_card" => "Aadhaar Card",
    "form_26as" => "Form 26AS", "ais_json" => "AIS (Annual Information Statement)",
    "form_16" => "Form 16 (from employer)", "rent_receipt" => "Rent Receipts",
    "rent_agreement" => "Rent Agreement", "home_loan_certificate" => "Home Loan Interest Certificate",
    "health_insurance_80d" => "Health Insurance Premium Receipt",
    "capital_gains_stmt" => "Capital Gains Statement", "trading_pnl_stmt" => "Trading P&L Statement",
    "crypto_statement" => "Crypto Exchange Statement", "bank_statement" => "Bank Statement",
    "pnl_statement" => "Profit & Loss Statement", "gst_return" => "GST Returns",
    "advance_tax_challan" => "Advance Tax Challans"
  }.freeze

  MANDATORY = %w[pan_card aadhaar_card form_26as ais_json].freeze

  TIPS = {
    "form_26as" => "Download from TRACES. Password-protected — we decrypt it automatically using your PAN + DOB.",
    "ais_json" => "Login → e-File → AIS → Download JSON. We auto-decrypt and parse it.",
    "form_16" => "Ask HR — usually available by June. Upload Part A + Part B.",
    "home_loan_certificate" => "Download from your bank's net banking (loan section).",
    "capital_gains_stmt" => "Or just sync your broker — we import trades directly."
  }.freeze
end
