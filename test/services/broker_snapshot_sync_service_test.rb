require "test_helper"

class BrokerSnapshotSyncServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      name: "Snapshot Test User",
      email: "snapshot_sync_test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @service = BrokerSnapshotSyncService.new(@user, broker: "dhan")
  end

  test "creates a snapshot row per holding" do
    rows = [
      { security_id: "1", trading_symbol: "TCS", total_qty: 10 }.with_indifferent_access,
      { security_id: "2", trading_symbol: "INFY", total_qty: 5 }.with_indifferent_access
    ]

    @service.sync_holdings!(rows)

    assert_equal 2, BrokerSnapshot.holdings.where(user: @user).count
    assert_equal %w[TCS INFY], BrokerSnapshot.holdings.where(user: @user).order(:security_id).pluck(:trading_symbol)
  end

  test "re-syncing updates existing rows instead of duplicating" do
    @service.sync_holdings!([ { security_id: "1", trading_symbol: "TCS", total_qty: 10 }.with_indifferent_access ])
    @service.sync_holdings!([ { security_id: "1", trading_symbol: "TCS", total_qty: 15 }.with_indifferent_access ])

    assert_equal 1, BrokerSnapshot.holdings.where(user: @user).count
    assert_equal 15, BrokerSnapshot.holdings.where(user: @user).first.data["total_qty"]
  end

  test "re-syncing removes holdings no longer present (sold off)" do
    @service.sync_holdings!([
      { security_id: "1", trading_symbol: "TCS", total_qty: 10 }.with_indifferent_access,
      { security_id: "2", trading_symbol: "INFY", total_qty: 5 }.with_indifferent_access
    ])
    @service.sync_holdings!([ { security_id: "1", trading_symbol: "TCS", total_qty: 10 }.with_indifferent_access ])

    assert_equal [ "TCS" ], BrokerSnapshot.holdings.where(user: @user).pluck(:trading_symbol)
  end

  test "holdings and positions are tracked independently" do
    @service.sync_holdings!([ { security_id: "1", trading_symbol: "TCS", total_qty: 10 }.with_indifferent_access ])
    @service.sync_positions!([ { security_id: "9", trading_symbol: "NIFTY FUT", net_qty: 1 }.with_indifferent_access ])

    assert_equal 1, BrokerSnapshot.holdings.where(user: @user).count
    assert_equal 1, BrokerSnapshot.positions.where(user: @user).count
  end
end
