require "test_helper"

class EmploymentTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Emp Tester", email: "employment_model@example.com", password: "password123", password_confirmation: "password123")
  end

  test "creates an employment record" do
    emp = @user.employments.create!(employer_name: "Test Corp", designation: "Engineer", start_date: Date.current - 2.years, is_current: true, monthly_ctc: 1500000)
    assert emp.persisted?
    assert_equal "Test Corp", emp.employer_name
  end

  test "fnf_settled_at is nil by default" do
    emp = @user.employments.create!(employer_name: "Active Corp", start_date: Date.current, is_current: true)
    assert_nil emp.fnf_settled_at
  end

  test "requires employer name" do
    emp = @user.employments.build(employer_name: nil, start_date: Date.current, is_current: true)
    assert_not emp.valid?
  end

  test "allows same employer name with different dates" do
    @user.employments.create!(employer_name: "Same Corp", start_date: Date.new(2020, 1, 1), is_current: false)
    emp = @user.employments.build(employer_name: "Same Corp", start_date: Date.new(2025, 1, 1), is_current: true)
    assert emp.valid?
  end
end
