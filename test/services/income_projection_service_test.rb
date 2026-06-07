require "test_helper"

class IncomeProjectionServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Test User",
      email: "test_income@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "should project recurring income with no end date indefinitely" do
    # Create a monthly template starting on May 1st, 2026
    template = @user.incomes.create!(
      source: "Salary",
      amount: 5000,
      income_date: Date.new(2026, 5, 1),
      is_recurring: true,
      frequency: "monthly"
    )

    # Check projection from May to July 2026 (should project for June and July)
    service = IncomeProjectionService.new(@user, Date.new(2026, 5, 1), Date.new(2026, 7, 31))
    results = service.call

    # Expected: template itself (May 1), plus projected June 1 and July 1. Total 3.
    assert_equal 3, results.length
    assert_equal [Date.new(2026, 7, 1), Date.new(2026, 6, 1), Date.new(2026, 5, 1)], results.map(&:income_date)
  end

  test "should not project recurring income after its end date" do
    # Create a monthly template starting on May 1st, 2026, ending on June 15th, 2026
    template = @user.incomes.create!(
      source: "Part-time job",
      amount: 1000,
      income_date: Date.new(2026, 5, 1),
      is_recurring: true,
      frequency: "monthly",
      end_date: Date.new(2026, 6, 15)
    )

    # Check projection from May to July 2026 (should only project May and June, NOT July)
    service = IncomeProjectionService.new(@user, Date.new(2026, 5, 1), Date.new(2026, 7, 31))
    results = service.call

    # Expected: template itself (May 1), plus projected June 1. Total 2. July 1 should be excluded.
    assert_equal 2, results.length
    assert_equal [Date.new(2026, 6, 1), Date.new(2026, 5, 1)], results.map(&:income_date)
  end

  test "should exclude projection in a month if the projected day itself falls after the end date" do
    # Create a monthly template starting on May 20th, 2026, ending on June 15th, 2026
    template = @user.incomes.create!(
      source: "Rent income",
      amount: 1500,
      income_date: Date.new(2026, 5, 20),
      is_recurring: true,
      frequency: "monthly",
      end_date: Date.new(2026, 6, 15)
    )

    # Check projection from May to July 2026
    service = IncomeProjectionService.new(@user, Date.new(2026, 5, 1), Date.new(2026, 7, 31))
    results = service.call

    # Expected: only template itself (May 20). June 20 is after June 15 end date.
    assert_equal 1, results.length
    assert_equal Date.new(2026, 5, 20), results.first.income_date
  end
end
