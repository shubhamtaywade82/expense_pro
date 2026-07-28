# frozen_string_literal: true

# Persists a broker's live holdings/positions as the current point-in-time
# state for (user, broker) — upserts what's still there, deletes what
# dropped out (sold holdings, closed positions). Not a trade ledger; each
# sync call replaces the prior snapshot for that kind.
class BrokerSnapshotSyncService
  def initialize(user, broker:)
    @user = user
    @broker = broker
  end

  def sync_holdings!(rows)
    sync_kind("holding", rows)
  end

  def sync_positions!(rows)
    sync_kind("position", rows)
  end

  private

  def sync_kind(kind, rows)
    synced_at = Time.current
    seen_ids = []

    rows.each do |row|
      security_id = row[:security_id].to_s
      next if security_id.blank?

      seen_ids << security_id
      snapshot = BrokerSnapshot.find_or_initialize_by(
        user: @user, broker: @broker, kind: kind, security_id: security_id
      )
      snapshot.trading_symbol = row[:trading_symbol]
      snapshot.data = row
      snapshot.synced_at = synced_at
      snapshot.save!
    end

    BrokerSnapshot.where(user: @user, broker: @broker, kind: kind).where.not(security_id: seen_ids).delete_all
  end
end
