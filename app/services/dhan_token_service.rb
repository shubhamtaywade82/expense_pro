# frozen_string_literal: true

# Fetches the current DhanHQ access token from the Render-deployed algo_trading_api.
# Falls back to env-var token if the remote service is unavailable.
# Mirrors the pattern from algo_trading_api's Dhan::TokenManager.
class DhanTokenService
  TOKEN_SERVICE_URL = ENV.fetch("DHAN_TOKEN_SERVICE_URL", "https://algo-trading-api.onrender.com/auth/dhan/token")
  TOKEN_ACCESS_TOKEN = ENV.fetch("DHAN_TOKEN_ACCESS_TOKEN", nil)

  class TokenUnavailableError < StandardError; end

  class << self
    def current_token!
      stored = DhanAccessToken.active
      return stored.access_token if stored.present?

      fetch_and_store!
    end

    def fetch_and_store!
      token_info = fetch_from_render_api || fetch_from_env
      raise TokenUnavailableError, "No DhanHQ token available. Set DHAN_ACCESS_TOKEN or ensure DHAN_TOKEN_SERVICE_URL is reachable." if token_info.nil?

      DhanAccessToken.create!(
        access_token: token_info[:access_token],
        expires_at: token_info[:expires_at]
      )

      token_info[:access_token]
    end

    def client_id
      ENV.fetch("DHAN_CLIENT_ID", ENV.fetch("CLIENT_ID", nil))
    end

    def build_client
      token = current_token!
      DhanHQ::Client.new(access_token: token, client_id: client_id)
    rescue TokenUnavailableError => e
      raise e
    end

    private

    def fetch_from_render_api
      return nil if TOKEN_ACCESS_TOKEN.blank? || TOKEN_SERVICE_URL.blank?

      response = HTTParty.get(
        TOKEN_SERVICE_URL,
        headers: {
          "Authorization" => "Bearer #{TOKEN_ACCESS_TOKEN}",
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

    def fetch_from_env
      token = ENV.fetch("DHAN_ACCESS_TOKEN", ENV.fetch("ACCESS_TOKEN", nil))
      return nil if token.blank?

      Rails.logger.info("[DhanTokenService] Using DHAN_ACCESS_TOKEN from environment.")
      { access_token: token, expires_at: 30.days.from_now }
    end
  end
end
