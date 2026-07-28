# frozen_string_literal: true

# The latest known holding/position for one security at one broker, for one
# user. Point-in-time state, not a trade ledger — each sync replaces what was
# there before (see BrokerSnapshotSyncService). Exists so pages can read fast
# from Postgres instead of hitting the broker's live API on every load.
class BrokerSnapshot < ApplicationRecord
  KINDS = %w[holding position].freeze

  belongs_to :user

  validates :kind, inclusion: { in: KINDS }

  scope :holdings, -> { where(kind: "holding") }
  scope :positions, -> { where(kind: "position") }
  scope :for_broker, ->(broker) { where(broker: broker) }
end
