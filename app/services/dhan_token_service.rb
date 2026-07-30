# frozen_string_literal: true

# Fetches the current user's DhanHQ access token: DB-configured (via the Dhan
# Settings UI, BrokerCredential) render token endpoint first, falling back to
# ENV vars if the user hasn't configured one. Mirrors the pattern from
# algo_trading_api's Dhan::TokenManager, scoped per-user.
#
# One concrete broker adapter (BROKER = "dhan") over the broker-generic
# BrokerCredential/BrokerAccessToken tables, so adding CoinDCX or Delta
# Exchange India later is a new *TokenService, not a schema change.
class DhanTokenService
  BROKER = "dhan"
  DEFAULT_TOKEN_SERVICE_URL = "https://algo-trading-api.onrender.com/auth/dhan/token"

  class TokenUnavailableError < StandardError; end
  class UserRequiredError < StandardError; end

  class << self
    def current_token!
      user = require_user!
      return Current.dhan_access_token if Current.dhan_access_token.present?

      stored = BrokerAccessToken.active(user, broker: BROKER)
      if stored.present?
        Current.dhan_access_token = stored.access_token
        return stored.access_token
      end

      fetch_and_store!
    end

    def fetch_and_store!
      user = require_user!
      token_info = fetch_from_render_api(user) || fetch_from_env(user)
      if token_info.nil?
        raise TokenUnavailableError,
              "No DhanHQ token available for #{user.email}. Configure it in Dhan Settings or set DHAN_ACCESS_TOKEN."
      end

      BrokerAccessToken.create!(
        user: user,
        broker: BROKER,
        access_token: token_info[:access_token],
        expires_at: token_info[:expires_at]
      )

      Current.dhan_access_token = token_info[:access_token]
      token_info[:access_token]
    end

    def client_id
      credential = Current.user && credential_for(Current.user)
      credential&.client_id.presence || ENV.fetch("DHAN_CLIENT_ID", ENV.fetch("CLIENT_ID", nil))
    end

    # Used as DhanHQ's on_token_expired hook: discards the stale record,
    # clears the request-scoped cache, and fetches a fresh one immediately
    # (ignoring any cached non-expired row).
    def force_refresh!
      Current.dhan_access_token = nil
      fetch_and_store!
    end

    private

    def require_user!
      Current.user || raise(UserRequiredError, "No current user set for DhanTokenService")
    end

    def credential_for(user)
      BrokerCredential.find_by(user: user, broker: BROKER)
    end

    def fetch_from_render_api(user)
      credential = credential_for(user)
      url = credential&.token_service_url.presence || ENV.fetch("DHAN_TOKEN_SERVICE_URL", DEFAULT_TOKEN_SERVICE_URL)
      bearer = credential&.token_service_secret.presence || ENV.fetch("DHAN_TOKEN_ACCESS_TOKEN", nil)
      return nil if bearer.blank? || url.blank?

      response = HTTParty.get(
        url,
        headers: {
          "Authorization" => "Bearer #{bearer}",
          "Content-Type" => "application/json"
        },
        timeout: 10
      )

      return nil unless response.success?

      body = response.parsed_response
      access_token = body["access_token"]
      expires_at = body["expires_at"] ? Time.parse(body["expires_at"]) : 30.days.from_now

      return nil if access_token.blank?

      { access_token: access_token, expires_at: expires_at }
    rescue StandardError => e
      Rails.logger.warn("[DhanTokenService] Render API fetch failed: #{e.message}")
      nil
    end

    def fetch_from_env(user)
      credential = credential_for(user)
      token = credential&.fallback_access_token.presence || ENV.fetch("DHAN_ACCESS_TOKEN", ENV.fetch("ACCESS_TOKEN", nil))
      return nil if token.blank?

      Rails.logger.info("[DhanTokenService] Using fallback access token for #{user.email}.")
      { access_token: token, expires_at: 30.days.from_now }
    end
  end
end
