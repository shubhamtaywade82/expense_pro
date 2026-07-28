require "test_helper"

class Api::V1::BillsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test User",
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @category = @user.categories.find_by!(name: "Rent")
    
    @bill = @user.monthly_bills.create!(
      category: @category,
      name: "Rent Bill",
      amount: 1000.00,
      due_date: 5,
      reminder_days: 3
    )
    # Log in and obtain JWT
    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    @token = JSON.parse(response.body)["token"]
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "should toggle paid status of a bill" do
    assert_not @bill.is_paid
    patch toggle_paid_api_v1_bill_url(@bill), headers: @headers
    assert_response :success

    @bill.reload
    assert @bill.is_paid

    # Toggle it back
    patch toggle_paid_api_v1_bill_url(@bill), headers: @headers
    assert_response :success

    @bill.reload
    assert_not @bill.is_paid
  end
end
