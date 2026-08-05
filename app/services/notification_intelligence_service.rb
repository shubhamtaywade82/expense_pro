# app/services/notification_intelligence_service.rb
class NotificationIntelligenceService
  def initialize(user)
    @user = user
    @fy = Date.today.month >= 4 ? Date.today.year : Date.today.year - 1
  end

  def analyze_and_create_notifications
    Rails.logger.info "Running notification analysis for User #{@user.id}"
    
    check_tax_compliance
    check_cash_flow
    check_investment_intelligence
    check_document_gaps
    
    Rails.logger.info "Notification analysis complete for User #{@user.id}"
  end

  private

  def create_notification(subject, message, category, payload = {})
    @user.notifications.create!(
      subject: subject,
      message: message,
      category: category,
      payload: payload.merge(priority: payload[:priority] || 3)
    )
  end

  # ── Tax Compliance Checks ──
  def check_tax_compliance
    check_ais_mismatch
    check_form_16_missing
    check_fo_loss_limit
    check_advance_tax_due
  end

  def check_ais_mismatch
    # Check if user has trades but no matching AIS data uploaded
    trade_count = @user.trades.where(executed_at: Date.new(@fy, 4, 1)..).count
    ais_docs = @user.tax_documents.where(document_type: :ais_json, financial_year: @fy)
    
    if trade_count > 10 && ais_docs.empty?
      create_notification(
        "AIS Data Mismatch Detected",
        "You have #{trade_count} trades this FY but no AIS/26AS data uploaded. This may cause tax filing issues.",
        "tax",
        {
          action_url: "/documents/upload?type=ais",
          action_label: "Upload AIS/26AS",
          priority: 1
        }
      )
    end
  end

  def check_form_16_missing
    form16 = @user.tax_documents.where(document_type: :form_16, financial_year: @fy).first
    salary_income = @user.incomes.where(income_source: :salary, income_date: Date.new(@fy, 4, 1)..).sum(:amount)
    
    if salary_income > 0 && !form16
      create_notification(
        "Form 16 Not Uploaded",
        "Salary income detected but Form 16 is missing. Upload it to auto-calculate TDS and deductions.",
        "tax",
        {
          action_url: "/documents/upload?type=form16",
          action_label: "Upload Form 16",
          priority: 2
        }
      )
    end
  end

  def check_fo_loss_limit
    fo_losses = @user.trades
                     .where(segment: :fno, executed_at: Date.new(@fy, 4, 1)..)
                     .where("pnl < 0")
                     .sum(:pnl)
    
    if fo_losses < -150_000 # ₹1.5L limit for non-business F&O
      create_notification(
        "F&O Loss Limit Warning",
        "Your F&O losses (₹#{fo_losses.abs.round(2)}) exceed ₹1.5L. Consider opting for presumptive taxation or maintaining books.",
        "tax",
        {
          action_url: "/tax/fno-analysis",
          action_label: "Review F&O Strategy",
          priority: 1
        }
      )
    end
  end

  def check_advance_tax_due
    # Simplified check - in production would call copilot service
    estimated_tax = 50_000 # Placeholder
    advance_paid = @user.advance_tax_payments.where(financial_year: @fy).sum(:amount)
    
    if estimated_tax > advance_paid + 10_000
      create_notification(
        "Advance Tax Due",
        "You may owe approximately ₹#{(estimated_tax - advance_paid).round(2)} in advance tax for Q#{@fy}.",
        "tax",
        {
          action_url: "/tax/advance-tax",
          action_label: "Pay Advance Tax",
          priority: 1
        }
      )
    end
  end

  # ── Cash Flow Checks ──
  def check_cash_flow
    check_spending_spike
    check_subscription_renewals
    check_low_balance
    check_bill_payments_due
  end

  def check_spending_spike
    this_month = Date.today.beginning_of_month..Date.today.end_of_month
    last_month = (Date.today - 1.month).beginning_of_month..(Date.today - 1.month).end_of_month
    
    this_expenses = @user.expenses.where(expense_date: this_month).sum(:amount)
    last_expenses = @user.expenses.where(expense_date: last_month).sum(:amount)
    
    if last_expenses > 0 && this_expenses > last_expenses * 1.5
      increase_pct = ((this_expenses - last_expenses) / last_expenses * 100).round(1)
      create_notification(
        "Spending Spike Alert",
        "Your expenses are up #{increase_pct}% this month (₹#{this_expenses} vs ₹#{last_expenses}).",
        "cash_flow",
        {
          action_url: "/expenses?period=this_month",
          action_label: "View Expenses",
          priority: 3
        }
      )
    end
  end

  def check_subscription_renewals
    upcoming = @user.monthly_bills.where(next_due_date: Date.today..(Date.today + 7.days))
    
    upcoming.each do |bill|
      create_notification(
        "Subscription Renewing Soon",
        "#{bill.name} (₹#{bill.amount}) renews on #{bill.next_due_date.strftime('%b %d')}.",
        "cash_flow",
        {
          action_url: "/bills/#{bill.id}/edit",
          action_label: "Manage Subscription",
          priority: 4
        }
      )
    end
  end

  def check_low_balance
    low_accounts = @user.financial_accounts
                          .where(account_type: [:savings_bank, :current_account])
                          .where("current_balance < 10000")
    
    low_accounts.each do |account|
      create_notification(
        "Low Balance Alert",
        "#{account.name} balance is ₹#{account.current_balance}. Consider transferring funds.",
        "cash_flow",
        {
          action_url: "/accounts/#{account.id}",
          action_label: "View Account",
          priority: 2
        }
      )
    end
  end

  def check_bill_payments_due
    due_bills = @user.monthly_bills.where(next_due_date: Date.today..(Date.today + 3.days), paid: false)
    
    due_bills.each do |bill|
      create_notification(
        "Bill Payment Due",
        "#{bill.name} of ₹#{bill.amount} is due on #{bill.next_due_date.strftime('%b %d')}.",
        "cash_flow",
        {
          action_url: "/bills/#{bill.id}/pay",
          action_label: "Pay Now",
          priority: 1
        }
      )
    end
  end

  # ── Investment Intelligence ──
  def check_investment_intelligence
    check_portfolio_rebalancing
    check_dividend_tracking
    check_sip_failures
  end

  def check_portfolio_rebalancing
    # Simplified logic - in production would use target allocation
    equity_investments = @user.investments.where(asset_class: [:long_term_equity, :swing_trading])
    total_value = equity_investments.sum(&:current_value)
    
    if total_value > 500_000
      # Check concentration risk
      top_holding = equity_investments.max_by(&:current_value)
      if top_holding && top_holding.current_value > total_value * 0.4
        create_notification(
          "Portfolio Concentration Risk",
          "#{top_holding.name} comprises #{((top_holding.current_value / total_value) * 100).round(1)}% of your portfolio. Consider diversifying.",
          "investment",
          {
            action_url: "/investments/rebalance",
            action_label: "Rebalance Portfolio",
            priority: 3
          }
        )
      end
    end
  end

  def check_dividend_tracking
    recent_dividends = @user.incomes
                            .where(income_source: :dividend, income_date: (Date.today - 30.days)..Date.today)
    
    if recent_dividends.any?
      total = recent_dividends.sum(:amount)
      create_notification(
        "Dividend Income Received",
        "You received ₹#{total} in dividends this month from #{recent_dividends.count} companies.",
        "investment",
        {
          action_url: "/incomes?source=dividend",
          action_label: "View Details",
          priority: 5
        }
      )
    end
  end

  def check_sip_failures
    # Placeholder - would integrate with MF tracking
    # In production, check for missed SIP payments
  end

  # ── Document Gap Analysis ──
  def check_document_gaps
    check_missing_deduction_proofs
  end

  def check_missing_deduction_proofs
    fy_start = Date.new(@fy, 4, 1)
    
    # Check for 80C investments without proofs
    eight_c_investments = @user.investments
                               .where("metadata->>'eligible_for_80c' = 'true'")
                               .where(purchase_date: fy_start..)
    
    proof_docs = @user.tax_documents
                      .where(document_type: [:investment_proof, :insurance_premium], financial_year: @fy)
    
    if eight_c_investments.count > 0 && proof_docs.empty?
      create_notification(
        "Missing 80C Proofs",
        "You have #{eight_c_investments.count} investments eligible for 80C but no proofs uploaded.",
        "document",
        {
          action_url: "/documents/upload?type=80c_proof",
          action_label: "Upload Proofs",
          priority: 2
        }
      )
    end
    
    # Check for health insurance premium without proof
    health_expenses = @user.expenses
                         .where(category_id: @user.categories.find_by(name: "Health")&.id)
                         .where(expense_date: fy_start..)
                         .where("amount > 25000")
    
    if health_expenses.any? && proof_docs.empty?
      create_notification(
        "Missing 80D Health Insurance Proof",
        "Health expenses detected but no insurance premium proof uploaded for 80D deduction.",
        "document",
        {
          action_url: "/documents/upload?type=80d_proof",
          action_label: "Upload Proof",
          priority: 2
        }
      )
    end
  end
end
