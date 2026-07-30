class TaxDocument < ApplicationRecord
  belongs_to :user
  
  has_one_attached :file
  has_one_attached :preview_image

  enum :document_type, {
    # Universal
    pan_card:            "pan_card",
    aadhaar_card:        "aadhaar_card",
    form_26as:           "form_26as",
    ais_json:            "ais_json",
    tis_json:            "tis_json",
    advance_tax_challan: "advance_tax_challan",
    previous_itr:        "previous_itr",

    # Salaried
    form_16:             "form_16",
    form_16a:            "form_16a",
    salary_slip:         "salary_slip",
    rent_receipt:        "rent_receipt",
    rent_agreement:      "rent_agreement",
    home_loan_certificate: "home_loan_certificate",
    insurance_premium:   "insurance_premium",
    health_insurance_80d: "health_insurance_80d",
    ppf_passbook:        "ppf_passbook",
    elss_statement:      "elss_statement",
    nps_statement:       "nps_statement",
    tuition_receipt:     "tuition_receipt",
    donation_80g:        "donation_80g",
    education_loan_cert: "education_loan_cert",
    bank_interest_cert:  "bank_interest_cert",
    savings_passbook:    "savings_passbook",

    # Trader
    capital_gains_stmt:  "capital_gains_stmt",
    trading_pnl_stmt:    "trading_pnl_stmt",
    trading_ledger:      "trading_ledger",
    crypto_statement:    "crypto_statement",
    bank_statement:      "bank_statement",

    # Business
    pnl_statement:       "pnl_statement",
    balance_sheet:       "balance_sheet",
    gst_return:          "gst_return",
    purchase_register:   "purchase_register",
    sales_register:      "sales_register",
    expense_invoice:     "expense_invoice",
    depreciation_schedule: "depreciation_schedule"
  }

  enum :status, {
    uploaded:    0,
    decrypting:  1,
    processing:  2,
    extracted:   3,
    verified:    4,
    mismatch:    5,
    failed:      6,
    rejected:    7
  }, default: :uploaded

  enum :source, { user_upload: 0, auto_import: 1, generated: 2 }, default: :user_upload

  validates :document_type, :financial_year, presence: true
  validate :file_constraints

  scope :for_fy, ->(fy) { where(financial_year: fy) }
  scope :actionable, -> { where(status: %i[extracted mismatch]) }

  MAX_PDF_MB = 2
  MAX_IMAGE_MB = 1
  ACCEPTED_TYPES = %w[
    application/pdf image/jpeg image/png
  ].freeze

  def requires_decryption?
    %w[form_26as ais_json].include?(document_type)
  end

  def requires_ocr?
    OCR_PARSERS.key?(document_type)
  end

  def parser
    DocumentParsers::Registry.for(document_type) if requires_ocr?
  end

  def extracted_amount
    return nil unless extracted_data.is_a?(Hash) && requires_ocr?
    # Simple implementation, expand as needed
    extracted_data["taxable_salary"] || extracted_data["amount"]
  end

  def fy_label
    "#{financial_year}-#{(financial_year + 1) % 100}"
  end

  private

  def file_constraints
    return unless file.attached?

    unless ACCEPTED_TYPES.include?(file.content_type)
      errors.add(:file, "must be PDF, JPG, or PNG")
      return
    end

    limit = file.content_type == "application/pdf" ? MAX_PDF_MB : MAX_IMAGE_MB
    if file.byte_size > limit.megabytes
      errors.add(:file, "must be under #{limit}MB (income tax portal limit)")
    end
  end

  OCR_PARSERS = {
    "pan_card"            => "DocumentParsers::PanParser",
    "form_16"             => "DocumentParsers::Form16Parser",
    "form_16a"            => "DocumentParsers::Form16AParser",
    "form_26as"           => "DocumentParsers::Form26ASParser",
    "ais_json"            => "DocumentParsers::AisParser",
    "advance_tax_challan" => "DocumentParsers::ChallanParser",
    "rent_receipt"        => "DocumentParsers::RentReceiptParser",
    "home_loan_certificate" => "DocumentParsers::HomeLoanCertParser",
    "health_insurance_80d" => "DocumentParsers::InsurancePremiumParser",
    "capital_gains_stmt"  => "DocumentParsers::CapitalGainsParser",
    "bank_statement"      => "DocumentParsers::BankStatementParser",
    "expense_invoice"     => "DocumentParsers::InvoiceParser",
    "tuition_receipt"     => "DocumentParsers::TuitionReceiptParser",
    "donation_80g"        => "DocumentParsers::DonationParser"
  }.freeze
end
