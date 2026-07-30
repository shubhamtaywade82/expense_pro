require "test_helper"

class IncomeTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Income Tester", email: "income_model2@example.com", password: "password123")
  end

  test "creates a basic income" do
    income = @user.incomes.create!(source: "Test Income", amount: 50000, income_date: Date.current, is_recurring: false)
    assert income.persisted?
    assert_equal 50000, income.amount
  end

  test "gross to net calculation logic" do
    income = @user.incomes.create!(
      source: "Salary",
      gross_amount: 100000,
      tax_deducted: 10000,
      pf_deducted: 5000,
      other_deductions: 2000,
      income_date: Date.current,
      is_recurring: false
    )
    assert_equal 83000, income.amount # 100k - 10k - 5k - 2k
  end

  test "auto closes older ongoing templates" do
    old_template = @user.incomes.create!(
      source: "Company A", amount: 50000, income_date: Date.new(2025, 1, 1), is_recurring: true
    )
    
    assert old_template.ongoing?

    new_template = @user.incomes.create!(
      source: "Company A", amount: 60000, income_date: Date.new(2026, 1, 1), is_recurring: true
    )

    old_template.reload
    assert_not old_template.ongoing?
    assert_equal Date.new(2025, 12, 31), old_template.end_date
  end

  test "validates older recurring rule must have end date if not auto-closed" do
    new_template = @user.incomes.create!(
      source: "Company B", amount: 60000, income_date: Date.new(2026, 1, 1), is_recurring: true
    )
    
    # Trying to insert an older template without an end date should fail
    # because it can't be ongoing if a newer one exists. (The before_save auto-close is for existing older rules)
    # Wait, the before_save will actually trigger and close it!
    # Let's test the gap_info instead.
    
    old_template = @user.incomes.new(
      source: "Company B", amount: 50000, income_date: Date.new(2025, 1, 1), is_recurring: true
    )
    
    # It auto-closed it to one day before the newer template?
    # No, close_older_ongoing_templates looks for older templates when saving the current one.
    # Here we are saving an older one, so the newer one is already there.
    assert_not old_template.valid?
    assert_includes old_template.errors[:end_date], "must be specified for historical recurring rules. Only the latest recurring rule can be ongoing."
  end

  test "gap_info overlap and gap detection" do
    t1 = @user.incomes.create!(source: "Job", amount: 10, income_date: Date.new(2025, 1, 1), is_recurring: true, end_date: Date.new(2025, 6, 1))
    t2 = @user.incomes.create!(source: "Job", amount: 20, income_date: Date.new(2025, 6, 15), is_recurring: true)

    assert_match /Gap: Uncovered gap of 13 days/, t1.gap_info
    
    t1.update(end_date: Date.new(2025, 6, 20))
    assert_match /Overlap: Overlaps with next rule by 6 days/, t1.gap_info
    
    t1.update(end_date: Date.new(2025, 6, 14))
    assert_match /Continuous: Seamless transition/, t1.gap_info
  end
end
