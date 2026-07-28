# frozen_string_literal: true

module Api
  module V1
    # Reads persisted broker holdings/positions from Postgres — no live
    # broker API call, so this is fast and broker-agnostic (works the same
    # once a second broker is added). Freshness comes from whatever last
    # called BrokerSnapshotSyncService (Dhan holdings/positions/refresh_token).
    class BrokerSnapshotsController < BaseController
      def index
        snapshots = current_user.broker_snapshots

        render json: {
          holdings: snapshots.holdings.map { |s| snapshot_json(s) },
          positions: snapshots.positions.map { |s| snapshot_json(s) },
          last_synced_at: snapshots.maximum(:synced_at)&.iso8601
        }
      end

      private

      def snapshot_json(snapshot)
        snapshot.data.merge(
          "broker" => snapshot.broker,
          "synced_at" => snapshot.synced_at.iso8601
        )
      end
    end
  end
end
