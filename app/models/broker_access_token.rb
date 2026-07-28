# frozen_string_literal: true

# A fetched access token for one user's connection to one broker (Dhan,
# CoinDCX, Delta Exchange India, ...). Scoped by (user, broker) so a user can
# hold live tokens for multiple brokers at once.
class BrokerAccessToken < ApplicationRecord
  belongs_to :user

  scope :non_expired, -> { where("expires_at > ?", Time.current) }
  scope :newest_first, -> { order(created_at: :desc) }

  class << self
    def active(user, broker:)
      where(user: user, broker: broker).non_expired.newest_first.first
    end

    def valid?(user, broker:)
      active(user, broker: broker).present?
    end
  end
end
