# frozen_string_literal: true

DhanHQ.configure_with_env

client_id = ENV["DHAN_CLIENT_ID"].presence || ENV["CLIENT_ID"].presence
DhanHQ.configuration.client_id = client_id if client_id

DhanHQ.configure do |config|
  # Token is fetched (and DB-cached) via DhanTokenService, which pulls from the
  # Render-deployed algo_trading_api's /auth/dhan/token, falling back to ENV.
  config.access_token_provider = -> { DhanTokenService.current_token! }

  config.on_token_expired = lambda do |error|
    Rails.logger.warn("[DhanHQ] Auth failure (#{error.class}); forcing token refresh")
    DhanTokenService.force_refresh!
  end
end
