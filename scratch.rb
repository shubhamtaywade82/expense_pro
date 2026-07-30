user = User.create!(name: "Test", email: "test#{Time.now.to_i}@example.com", password: "password123")
category = Category.create!(name: "Loans", category_type: "expense", user: user)
loan = user.loans.create!(
  name: "Home Loan",
  loan_type: "home",
  principal_amount: 50_00_000,
  interest_rate: 8.5,
  tenure_months: 240,
  start_date: Date.new(2025, 4, 1),
  category: category,
  occupancy: "self_occupied"
)
puts "EMI Payments count: #{loan.emi_payments.count}"
puts "Interest sum: #{loan.emi_payments.where(due_date: Date.new(2025,4,1)..Date.new(2026,3,31)).sum(:interest_amount)}"
