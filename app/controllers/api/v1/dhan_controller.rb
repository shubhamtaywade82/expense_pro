# frozen_string_literal: true

module Api
  module V1
    class DhanController < BaseController
      before_action :ensure_dhan_configured, except: %i[credential update_credential]

      def token_status
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

      def refresh_token
        DhanTokenService.fetch_and_store!
        token = BrokerAccessToken.active(current_user, broker: DhanTokenService::BROKER)
        render json: {
          connected: true,
          expires_at: token.expires_at.iso8601,
          client_id: DhanTokenService.client_id,
          message: "Token refreshed successfully"
        }
      rescue DhanTokenService::TokenUnavailableError => e
        render json: { connected: false, error: e.message }, status: :service_unavailable
      end

      def profile
        svc = DhanDataService.new
        render json: svc.profile
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def positions
        svc = DhanDataService.new
        render json: svc.positions
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def holdings
        svc = DhanDataService.new
        render json: svc.holdings
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def orders
        svc = DhanDataService.new
        render json: svc.orders
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def trade_book
        svc = DhanDataService.new
        render json: svc.trade_book
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def trade_history
        from = params[:from_date] || 30.days.ago.to_date.to_s
        to   = params[:to_date]   || Date.current.to_s
        page = (params[:page] || 0).to_i

        svc = DhanDataService.new
        render json: svc.trade_history(from_date: from, to_date: to, page: page)
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def fund_limits
        svc = DhanDataService.new
        render json: svc.fund_limits
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def ledger
        from = params[:from_date] || 30.days.ago.to_date.to_s
        to   = params[:to_date]   || Date.current.to_s

        svc = DhanDataService.new
        render json: svc.ledger(from_date: from, to_date: to)
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      # Broker connection settings — secrets are write-only, never re-serialized.
      def credential
        cred = BrokerCredential.find_by(user: current_user, broker: DhanTokenService::BROKER)
        render json: credential_json(cred)
      end

      def update_credential
        cred = BrokerCredential.find_or_initialize_by(user: current_user, broker: DhanTokenService::BROKER)
        cred.client_id = params[:client_id] if params.key?(:client_id)
        cred.token_service_url = params[:token_service_url] if params.key?(:token_service_url)
        cred.token_service_secret = params[:token_service_secret] if params[:token_service_secret].present?
        cred.fallback_access_token = params[:fallback_access_token] if params[:fallback_access_token].present?
        cred.save!

        # Settings changed — force a fresh token fetch under the new config next time it's needed.
        BrokerAccessToken.where(user: current_user, broker: DhanTokenService::BROKER).delete_all

        render json: credential_json(cred).merge(message: "Broker settings saved")
      end

      private

      def credential_json(cred)
        {
          client_id: cred&.client_id,
          token_service_url: cred&.token_service_url,
          has_token_service_secret: cred&.token_service_secret.present?,
          has_fallback_access_token: cred&.fallback_access_token.present?
        }
      end

      def ensure_dhan_configured
        return if DhanTokenService.client_id.present?

        render json: { error: "DHAN_CLIENT_ID not configured" }, status: :service_unavailable
      end
    end
  end
end
