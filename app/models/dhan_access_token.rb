# frozen_string_literal: true

class DhanAccessToken < ApplicationRecord
  belongs_to :user

  scope :non_expired, -> { where("expires_at > ?", Time.current) }
  scope :newest_first, -> { order(created_at: :desc) }

  class << self
    def active(user)
      where(user: user).non_expired.newest_first.first
    end

    def valid?(user)
      active(user).present?
    end
  end
end
