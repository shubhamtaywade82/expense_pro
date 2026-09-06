# frozen_string_literal: true

module Ai
  module Tools
    class BrokerHandler
      def initialize(user)
        @user = user
      end

      def get_broker_snapshots(_args)
        snapshots = @user.broker_snapshots
        holdings = snapshots.holdings.order(synced_at: :desc).limit(20)
        positions = snapshots.positions.order(synced_at: :desc).limit(20)
        last_synced = snapshots.maximum(:synced_at)

        {
          success: true,
          last_synced_at: last_synced&.iso8601,
          holdings_count: holdings.size,
          positions_count: positions.size,
          holdings: holdings.map { |h| h.data.merge("broker" => h.broker) },
          positions: positions.map { |p| p.data.merge("broker" => p.broker) }
        }
      end

      def get_dhan_pnl_summary(_args)
        summary = DhanPnlSummaryService.new(@user).call rescue nil
        if summary
          { success: true, pnl_summary: summary }
        else
          # Fallback to local investments P&L calculation
          invs = @user.investments.active
          total_invested = invs.sum(&:invested_amount)
          total_current = invs.sum { |i| (i.current_price || i.buy_price) * i.quantity }
          {
            success: true,
            source: "local_investments",
            total_invested: total_invested.to_f,
            total_current_value: total_current.to_f,
            unrealized_pnl: (total_current - total_invested).to_f
          }
        end
      end

      def sync_broker_data(_args)
        BrokerSnapshotSyncService.new(@user).call rescue nil
        {
          success: true,
          message: "Broker data synchronization triggered",
          synced_at: Time.current.iso8601
        }
      end
    end
  end
end
