# frozen_string_literal: true

class NotificationIntelligenceService
  def initialize(user)
    @user = user
    @fy = Date.today.month >= 4 ? Date.today.year : Date.today.year - 1
  end

  def analyze_and_create_notifications
    check_tax_compliance
    check_cash_flow
    check_investment_intelligence
    check_document_gaps
  end

  private

  def notify(subject, message, category, payload = {})
    @user.notifications.create!(
      subject: subject,
      message: message,
      category: category,
      payload: payload.merge(priority: payload[:priority] || 3)
    )
  end

  # ── Tax Compliance ──────────────────────────────────────────────────────────

  def check_tax_compliance
    check_ais_mismatch
    check_form_16_missing
    check_fo_loss_limit
  end

  def check_ais_mismatch
    trade_count = @user.trades.for_fy(@fy).count
    ais_docs = @user.tax_documents.where(document_type: :ais_json, financial_year: @fy)
    return unless trade_count > 10 && ais_docs.empty?

    notify(
      "AIS Data Mismatch Detected",
      "You have #{trade_count} trades this FY but no AIS/26AS data uploaded. This may cause tax filing issues.",
      "tax",
      action_url: "/documents/upload?type=ais", action_label: "Upload AIS/26AS", priority: 1
    )
  end

  def check_form_16_missing
    form16 = @user.tax_documents.where(document_type: :form_16, financial_year: @fy).first
    salary_income = @user.incomes.for_fy(@fy).salary.sum(:amount)
    return unless salary_income > 0 && !form16

    notify(
      "Form 16 Not Uploaded",
      "Salary income detected but Form 16 is missing. Upload it to auto-calculate TDS and deductions.",
      "tax",
      action_url: "/documents/upload?type=form16", action_label: "Upload Form 16", priority: 2
    )
  end

  def check_fo_loss_limit
    fo_losses = @user.investments
                     .where(asset_class: "non_speculative_fo")
                     .for_fy(@fy)
                     .select { |i| i.total_pnl < 0 }
                     .sum(&:total_pnl)
    return unless fo_losses < -150_000

    notify(
      "F&O Loss Limit Warning",
      "Your F&O losses (₹#{fo_losses.abs.round(2)}) exceed ₹1.5L. Consider opting for presumptive taxation or maintaining books.",
      "tax",
      action_url: "/tax/fno-analysis", action_label: "Review F&O Strategy", priority: 1
    )
  end

  # ── Cash Flow ───────────────────────────────────────────────────────────────

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
    return unless last_expenses > 0 && this_expenses > last_expenses * 1.5

    pct = ((this_expenses - last_expenses) / last_expenses * 100).round(1)
    notify(
      "Spending Spike Alert",
      "Your expenses are up #{pct}% this month (₹#{this_expenses} vs ₹#{last_expenses}).",
      "cash_flow",
      action_url: "/expenses?period=this_month", action_label: "View Expenses", priority: 3
    )
  end

  def check_subscription_renewals
    today_day = Date.current.day
    @user.monthly_bills.active.where(due_date: today_day..(today_day + 7)).each do |bill|
      notify(
        "Subscription Renewing Soon",
        "#{bill.name} (₹#{bill.amount}) is due around day #{bill.due_date} of the month.",
        "cash_flow",
        action_url: "/bills", action_label: "Manage Subscription", priority: 4
      )
    end
  end

  def check_low_balance
    @user.financial_accounts.where("balance < 10000").each do |account|
      name = account.account_name || "Account"
      notify(
        "Low Balance Alert",
        "#{name} balance is ₹#{account.balance}. Consider transferring funds.",
        "cash_flow",
        action_url: "/accounts/#{account.id}", action_label: "View Account", priority: 2
      )
    end
  end

  def check_bill_payments_due
    today_day = Date.current.day
    @user.monthly_bills.active.where(due_date: today_day..(today_day + 3), is_paid: false).each do |bill|
      notify(
        "Bill Payment Due",
        "#{bill.name} of ₹#{bill.amount} is due around day #{bill.due_date} of the month.",
        "cash_flow",
        action_url: "/bills", action_label: "Pay Now", priority: 1
      )
    end
  end

  # ── Investment Intelligence ─────────────────────────────────────────────────

  def check_investment_intelligence
    check_portfolio_rebalancing
    check_dividend_tracking
  end

  def check_portfolio_rebalancing
    equity = @user.investments.where(asset_class: %i[long_term_equity swing_trading])
    total_value = equity.sum(&:current_value)
    return unless total_value > 500_000

    top = equity.max_by(&:current_value)
    return unless top && top.current_value > total_value * 0.4

    pct = ((top.current_value / total_value) * 100).round(1)
    notify(
      "Portfolio Concentration Risk",
      "#{top.name} comprises #{pct}% of your portfolio. Consider diversifying.",
      "investment",
      action_url: "/investments/rebalance", action_label: "Rebalance Portfolio", priority: 3
    )
  end

  def check_dividend_tracking
    dividends = @user.incomes.dividend.where(income_date: (Date.current - 30.days)..Date.current)
    return if dividends.empty?

    notify(
      "Dividend Income Received",
      "You received ₹#{dividends.sum(:amount)} in dividends this month from #{dividends.count} companies.",
      "investment",
      action_url: "/incomes?source=dividend", action_label: "View Details", priority: 5
    )
  end

  # ── Document Gap Analysis ───────────────────────────────────────────────────

  def check_document_gaps
    fy_start = Date.new(@fy, 4, 1)
    proof_docs = @user.tax_documents.where(document_type: :insurance_premium, financial_year: @fy)

    eight_c = @user.investments.where(asset_class: "elss_80c").where("purchase_date >= ?", fy_start)
    if eight_c.exists? && proof_docs.empty?
      notify(
        "Missing 80C Proofs",
        "You have #{eight_c.count} investments eligible for 80C but no proofs uploaded.",
        "document",
        action_url: "/documents/upload?type=insurance_premium", action_label: "Upload Proofs", priority: 2
      )
    end

    health_cat = @user.categories.find_by(name: "Health")
    if health_cat
      health = @user.expenses.where(category_id: health_cat.id)
                            .where("expense_date >= ?", fy_start)
                            .where("amount > 25000")
      if health.exists? && proof_docs.empty?
        notify(
          "Missing 80D Health Insurance Proof",
          "Health expenses detected but no insurance premium proof uploaded for 80D deduction.",
          "document",
          action_url: "/documents/upload?type=insurance_premium", action_label: "Upload Proof", priority: 2
        )
      end
    end
  end
end
