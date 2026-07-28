require "test_helper"

class Api::V1::BrokerSnapshotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test User",
      email: "broker_snapshots_test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    BrokerSnapshotSyncService.new(@user, broker: "dhan").sync_holdings!(
      [ { security_id: "1", trading_symbol: "TCS", total_qty: 10, avg_cost_price: 3500 }.with_indifferent_access ]
    )

    post api_v1_session_url, params: { email: @user.email, password: "password123" }
    @token = JSON.parse(response.body)["token"]
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "returns persisted holdings without hitting the broker live" do
    get api_v1_broker_snapshots_url, headers: @headers
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 1, body["holdings"].size
    assert_equal "TCS", body["holdings"].first["trading_symbol"]
    assert_equal "dhan", body["holdings"].first["broker"]
    assert_empty body["positions"]
    assert body["last_synced_at"].present?
  end

  test "only returns the current user's snapshots" do
    other_user = User.create!(
      name: "Other User", email: "broker_snapshots_other@example.com",
      password: "password123", password_confirmation: "password123"
    )
    BrokerSnapshotSyncService.new(other_user, broker: "dhan").sync_holdings!(
      [ { security_id: "2", trading_symbol: "INFY", total_qty: 5 }.with_indifferent_access ]
    )

    get api_v1_broker_snapshots_url, headers: @headers
    body = JSON.parse(response.body)

    assert_equal 1, body["holdings"].size
    assert_equal "TCS", body["holdings"].first["trading_symbol"]
  end
end
