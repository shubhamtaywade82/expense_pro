class FilingReadinessService
  def initialize(user, financial_year)
    @user = user
    @fy = financial_year
  end

  def call
    tax = TaxCalculatorService.new(@user, @fy).call
    recon = ReconciliationService.new(@user, @fy).call
    checklist = DocumentChecklistService.new(@user, @fy).status

    blockers = []
    ca_required = []

    # ── Hard legal blockers that REQUIRE a CA ──
    if tax.dig(:tax_audit, :required)
      ca_required << {
        reason: "Tax Audit (Section 44AB)",
        detail: "Turnover is #{inr(tax.dig(:tax_audit, :turnover).to_f)} — above ₹#{inr(1_00_00_000)}. A CA must file the audit report (3CA/3CB-3CD) with their DSC before your ITR due date.",
        what_app_prepared: "Complete books, P&L, turnover calculation, and pre-filled ITR JSON"
      }
    end

    if tax.dig(:income, :foreign_assets).to_f > 0 || (defined?(@user.has_foreign_accounts?) && @user.has_foreign_accounts?)
      ca_required << {
        reason: "Foreign Assets (Schedule FA)",
        detail: "Foreign assets/accounts require Schedule FA disclosure. Errors here carry ₹10L+ penalties — strongly recommend CA review.",
        what_app_prepared: "All domestic schedules pre-filled"
      }
    end

    # ── Self-fixable blockers ──
    blockers += (recon[:checks] || [])
      .select { |c| c[:severity] == :critical }
      .map { |c| { type: :mismatch, item: c[:item], resolution: c[:resolution] } }

    blockers += checklist[:missing_required].map do |doc_type|
      { type: :missing_document, item: doc_type,
        resolution: "Upload #{doc_type.humanize} — required for your income profile" }
    end

    if needs_refund?(tax) && defined?(@user.refund_account_evc?) && !@user.refund_account_evc?
      blockers << { type: :bank_not_evc, item: "Refund bank account",
                    resolution: "Your refund account isn't marked EVC-validated. Validate it on the portal or refund will fail." }
    end

    if defined?(@user.aadhaar_linked?) && !@user.aadhaar_linked?
      blockers << { type: :aadhaar_not_linked, item: "PAN-Aadhaar linking",
                    resolution: "PAN must be linked to Aadhaar before filing. Check at incometax.gov.in." }
    end

    {
      financial_year: @fy,
      can_file_self: blockers.empty? && ca_required.empty?,
      ca_required: ca_required.any?,
      ca_required_reasons: ca_required,
      blockers: blockers,
      blocker_count: blockers.size,
      reconciliation_status: recon[:overall_status],
      recommended_form: tax[:recommended_itr_code] || tax[:recommended_itr],
      due_date: filing_due_date(tax),
      estimated_tax: tax.dig(:comparison, :recommended, :total_tax).to_f,
      next_steps: generate_next_steps(blockers, ca_required)
    }
  end

  private

  def filing_due_date(tax)
    # Non-audit: July 31 of AY. Audit: Oct 31. Transfer pricing: Nov 30.
    if tax.dig(:tax_audit, :required)
      "#{@fy + 1}-10-31"
    else
      "#{@fy + 1}-07-31"
    end
  end

  def needs_refund?(tax)
    tax.dig(:comparison, :recommended, :total_tax).to_f < tax.dig(:tds_summary, :total_tds).to_f
  end

  def generate_next_steps(blockers, ca_required)
    steps = []
    if ca_required.any?
      steps << "⚠️ Book a CA for: #{ca_required.map { |c| c[:reason] }.join(', ')}. Hand them the prepared file from this app."
    end
    blockers.first(3).each { |b| steps << b[:resolution] }
    steps << "Download pre-filled JSON" if blockers.empty? && ca_required.empty?
    steps << "Submit on incometax.gov.in → e-File → Upload JSON" if blockers.empty? && ca_required.empty?
    steps << "E-verify within 30 days via Aadhaar OTP (fastest) or EVC" if blockers.empty? && ca_required.empty?
    steps
  end

  def inr(n) = "₹#{n.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
end
