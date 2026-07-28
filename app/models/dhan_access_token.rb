# frozen_string_literal: true

class DhanAccessToken < ApplicationRecord
  CACHE_KEY = "dhan_access_token/active"
  CACHE_TTL = 60.seconds

  scope :non_expired, -> { where("expires_at > ?", Time.current) }
  scope :newest_first, -> { order(created_at: :desc) }

  class << self
    def active
      non_expired.newest_first.first
    end

    def valid?
      active.present?
    end
  end
end
