module Api
  module V1
    module Dhan
      class BaseController < ::Api::V1::BaseController
        rescue_from DhanHQ::Error, with: :render_service_unavailable

        before_action :ensure_dhan_configured

        private

        def snapshot_service
          @snapshot_service ||= BrokerSnapshotSyncService.new(current_user, broker: DhanTokenService::BROKER)
        end

        def sync_snapshots
          svc = DhanDataService.new
          snapshot_service.sync_holdings!(svc.holdings)
          snapshot_service.sync_positions!(svc.positions)
        rescue StandardError => e
          Rails.logger.warn("[DhanController] snapshot sync on refresh failed: #{e.message}")
        end

        def credential_json(cred)
          {
            client_id: cred&.client_id,
            token_service_url: cred&.token_service_url,
            has_token_service_secret: cred&.token_service_secret.present?,
            has_fallback_access_token: cred&.fallback_access_token.present?,
            auto_import_pnl: cred&.auto_import_pnl || false
          }
        end

        def ensure_dhan_configured
          return if DhanTokenService.client_id.present?

          render json: { error: "DHAN_CLIENT_ID not configured" }, status: :service_unavailable
        end

        def render_service_unavailable(exception)
          render json: { error: exception.message }, status: :service_unavailable
        end

        def run_auto_import_if_enabled
          cred = BrokerCredential.find_by(user: current_user, broker: DhanTokenService::BROKER)
          return unless cred&.auto_import_pnl?

          from = 7.days.ago.to_date.to_s
          to = Date.current.to_s
          DhanImportJob.perform_later(user_id: current_user.id, from_date: from, to_date: to)
        end
      end
    end
  end
end
