# frozen_string_literal: true

require "json"

namespace :import do
  desc "Import credit cards, loans, income, and expenses from Excel JSON dump"
  task excel: :environment do
    json_path = "/tmp/excel_dump.json"
    excel_path = ENV["EXCEL_PATH"] || "/mnt/c/Users/shubh/Downloads/Credit card and Loan tracker (corrected).xlsx"

    unless File.exist?(json_path)
      puts "Generating JSON dump from Excel using Python..."
      system("python3 -c \"import pandas as pd, json; xls = pd.ExcelFile('#{excel_path}'); data = {sheet: pd.read_excel(xls, sheet).where(pd.notnull, None).to_dict(orient='records') for sheet in xls.sheet_names}; open('#{json_path}', 'w').write(json.dumps(data, default=str))\"")
    end

    unless File.exist?(json_path)
      puts "Error: Dump file not found at #{json_path}"
      exit 1
    end

    puts "Starting import from #{json_path}..."
    data = JSON.parse(File.read(json_path))

    # Ensure Primary User exists
    user = User.find_or_create_by!(email: "shubhamtaywade82@gmail.com") do |u|
      u.name = "Shubham Taywade"
      u.password = "Password@123"
    end

    # Ensure Categories exist
    cat_personal_loan = Category.find_or_create_by!(user: user, name: "Personal Loan", category_type: "loan") { |c| c.color = "#ef4444" }
    cat_home_loan     = Category.find_or_create_by!(user: user, name: "Home Loan", category_type: "loan") { |c| c.color = "#f97316" }
    cat_credit_card   = Category.find_or_create_by!(user: user, name: "Credit Card Bill", category_type: "expense") { |c| c.color = "#8b5cf6" }
    cat_salary        = Category.find_or_create_by!(user: user, name: "Salary", category_type: "income") { |c| c.color = "#10b981" }

    cat_housing       = Category.find_or_create_by!(user: user, name: "Housing", category_type: "expense") { |c| c.color = "#3b82f6" }
    cat_food          = Category.find_or_create_by!(user: user, name: "Food", category_type: "expense") { |c| c.color = "#eab308" }
    cat_transport     = Category.find_or_create_by!(user: user, name: "Transport", category_type: "expense") { |c| c.color = "#06b6d4" }
    cat_utilities     = Category.find_or_create_by!(user: user, name: "Utilities", category_type: "expense") { |c| c.color = "#64748b" }
    cat_others        = Category.find_or_create_by!(user: user, name: "Others", category_type: "expense") { |c| c.color = "#a855f7" }

    # ---------------------------------------------------------
    # 1. Import Credit Cards as Monthly Bills
    # ---------------------------------------------------------
    if data["credit_cards"].present?
      puts "Importing Credit Cards..."
      data["credit_cards"].each do |row|
        card_name = row["Card Name"]&.to_s&.strip
        next if card_name.blank? || card_name.downcase == "total" || card_name == "None"

        due_date_num = row["Due Date"].to_i
        due_date_num = 1 if due_date_num < 1 || due_date_num > 31

        bill_amt = row["Bill "] || row["Outstanding Balance (₹)"] || 0
        bill_amt = bill_amt.to_d
        bill_amt = 0.01 if bill_amt <= 0

        bill = MonthlyBill.find_or_initialize_by(user: user, name: card_name)
        bill.category = cat_credit_card
        bill.amount = bill_amt
        bill.due_date = due_date_num
        bill.reminder_days = 3
        bill.is_active = true
        bill.is_paid = (row["status "]&.to_s&.strip&.downcase == "paid")
        bill.notes = "Limit: ₹#{row['Limit (₹)']}, Statement Date: #{row['Statement Date']}, Full Due: #{row['Full Due Date']}"
        bill.save!
        puts " - Saved Credit Card Bill: #{card_name} (₹#{bill.amount})"
      end
    end

    # ---------------------------------------------------------
    # 2. Import Loans
    # ---------------------------------------------------------
    if data["loans"].present?
      puts "Importing Loans..."
      data["loans"].each do |row|
        lender = row["Lender"]&.to_s&.strip
        loan_type_str = row["Loan Type"]&.to_s&.strip
        next if lender.blank? || lender.downcase == "total" || lender == "None"

        principal = row["Principal Amount (₹)"].to_d
        next if principal <= 0

        roi = (row["ROI (%)"] || 0).to_d
        tenure = (row["Tenure(months)"] || 12).to_i
        tenure = 12 if tenure <= 0

        raw_start = row["Start Date"]
        start_date = begin
          if raw_start.present?
            Date.strptime(raw_start.to_s, "%m/%d/%Y") rescue Date.parse(raw_start.to_s) rescue Date.current
          else
            Date.current
          end
        end

        category = loan_type_str.to_s.downcase.include?("home") ? cat_home_loan : cat_personal_loan
        type_code = loan_type_str.to_s.downcase.include?("home") ? "home" : "personal"

        name = "#{lender} (#{loan_type_str.presence || 'Loan'})"

        loan = Loan.find_or_initialize_by(user: user, name: name)
        loan.category = category
        loan.lender = lender
        loan.principal_amount = principal
        loan.interest_rate = roi
        loan.tenure_months = tenure
        loan.start_date = start_date
        loan.loan_type = type_code
        loan.notes = "Excel Import. Outstanding: ₹#{row['Outstanding Balance (₹)']}, EMI: ₹#{row['EMI (₹)']}, Status: #{row['Status']}"
        loan.save!
        puts " - Saved Loan: #{name} (₹#{principal}, EMI ₹#{loan.emi_amount})"

        if row["Status"]&.to_s&.strip&.downcase == "paid"
          loan.emi_payments.update_all(is_paid: true, paid_date: Date.current)
        end
      end
    end

    # ---------------------------------------------------------
    # 3. Import Income & Monthly Expenses / Budgets
    # ---------------------------------------------------------
    puts "Importing Income & Monthly Expenses..."
    Income.find_or_create_by!(user: user, source: "Monthly Salary / Income") do |inc|
      inc.amount = 145000.00
      inc.income_date = Date.current.beginning_of_month
      inc.is_recurring = true
      inc.frequency = "monthly"
      inc.is_received = true
      inc.notes = "Imported from Credit card and Loan tracker Excel"
    end

    # Budgets & Baseline Expenses
    expenses_data = [
      { category: cat_housing, name: "Housing", amount: 10000.00 },
      { category: cat_food, name: "Food", amount: 8000.00 },
      { category: cat_transport, name: "Transport", amount: 5000.00 },
      { category: cat_utilities, name: "Utilities", amount: 4000.00 },
      { category: cat_others, name: "Others", amount: 3000.00 }
    ]

    current_month = Date.current.month
    current_year = Date.current.year

    expenses_data.each do |e|
      Budget.find_or_create_by!(user: user, category: e[:category], month: current_month, year: current_year) do |b|
        b.amount = e[:amount]
        b.alert_threshold = 80
      end

      # Add monthly baseline expense record if not present for this month
      Expense.find_or_create_by!(user: user, category: e[:category], description: "#{e[:name]} Budget Baseline", expense_date: Date.current.beginning_of_month) do |exp|
        exp.amount = e[:amount]
        exp.payment_method = "other"
        exp.is_recurring = true
      end
    end

    puts "Data import successfully completed!"
  end
end
