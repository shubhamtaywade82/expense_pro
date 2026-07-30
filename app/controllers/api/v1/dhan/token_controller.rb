module Api
  module V1
    module Dhan
      class TokenController < BaseController
        skip_before_action :ensure_dhan_configured, only: %i[status refresh]

        def status
          token = BrokerAccessToken.active(current_user, broker: DhanTokenService::BROKER)
          if token
            render json: {
              connected: true,
              expires_at: token.expires_at.iso8601,
              client_id: DhanTokenService.client_id,
              token_preview: "#{token.access_token.first(12)}..."
            }
          else
            render json: { connected: false, message: "No valid token. Use refresh to fetch." }
          end
        end

        def refresh
          DhanTokenService.fetch_and_store!
          token = BrokerAccessToken.active(current_user, broker: DhanTokenService::BROKER)
          run_auto_import_if_enabled
          sync_snapshots
          render json: {
            connected: true,
            expires_at: token.expires_at.iso8601,
            client_id: DhanTokenService.client_id,
            message: "Token refreshed successfully"
          }
        rescue DhanTokenService::TokenUnavailableError => e
          render json: { connected: false, error: e.message }, status: :service_unavailable
        end
      end
    end
  end
end
