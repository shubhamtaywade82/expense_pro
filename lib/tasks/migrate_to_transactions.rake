namespace :data do
  desc "Migrate existing expenses and incomes to the unified Transaction model"
  task migrate_to_transactions: :environment do
    puts "Starting migration..."
    
    ActiveRecord::Base.transaction do
      # Make sure all users have a default financial account
      User.find_each do |user|
        default_account = user.financial_accounts.find_or_create_by!(
          account_name: "Default Cash Account",
          account_type: "cash"
        ) do |acc|
          acc.balance = 0.0
        end
        
        # Expenses
        user.expenses.find_each do |expense|
          next if Transaction.exists?(taggable: expense)
          
          Transaction.create!(
            user: user,
            financial_account: default_account,
            amount: expense.amount,
            txn_type: "expense",
            category_id: expense.category_id,
            txn_date: expense.expense_date,
            status: 1, # completed or whatever
            taggable: expense
          )
        end
        
        # Incomes
        user.incomes.find_each do |income|
          next if Transaction.exists?(taggable: income)
          
          Transaction.create!(
            user: user,
            financial_account: default_account,
            amount: income.amount,
            txn_type: "income",
            txn_date: income.income_date,
            status: 1,
            taggable: income
          )
        end
      end
    end
    
    puts "Migration complete! Validated #{Transaction.count} total transactions."
  end
end
