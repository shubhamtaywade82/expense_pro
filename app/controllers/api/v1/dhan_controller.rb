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

      def profile
        svc = DhanDataService.new
        render json: svc.profile
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def positions
        data = DhanDataService.new.positions
        snapshot_service.sync_positions!(data)
        render json: data
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      def holdings
        data = DhanDataService.new.holdings
        snapshot_service.sync_holdings!(data)
        render json: data
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

        result = DhanDataService.new.trade_history_all(from_date: from, to_date: to)
        render json: { trades: result[:trades], truncated: result[:truncated] }
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

      # Period P&L, bucketed the same way TaxCalculatorService reads Investments —
      # read-only, computes nothing into the DB.
      def pnl_summary
        from = params[:from_date] || 30.days.ago.to_date.to_s
        to   = params[:to_date]   || Date.current.to_s

        result = DhanDataService.new.trade_history_all(from_date: from, to_date: to)
        render json: {
          from_date: from,
          to_date: to,
          truncated: result[:truncated],
          segments: DhanPnlSummaryService.new(result[:trades]).call
        }
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      # Creates/updates one aggregate Investment per importable segment
      # (speculative_intraday, non_speculative_fo — auto-classified) for the
      # given period. Pass manual_asset_class (swing_trading or
      # long_term_equity) to also import the equity_delivery bucket under
      # that user-chosen classification — the trade log alone can't tell
      # STCG from LTCG without FIFO lot-matching.
      # Refuses to import on truncated trade data — a partial P&L is wrong,
      # not just incomplete, once it feeds into ITR/Investments.
      def import_to_investments
        from = params.require(:from_date)
        to = params.require(:to_date)
        manual_asset_class = params[:manual_asset_class].presence

        result = DhanDataService.new.trade_history_all(from_date: from, to_date: to)
        if result[:truncated]
          render json: { error: "Too many trades in this range to import accurately. Import This Month or This Quarter instead — each import is its own dated record, and ITR sums all of them across the year." },
                 status: :unprocessable_entity
          return
        end

        imported = DhanInvestmentImportService.new(
          current_user, from_date: from, to_date: to, trades: result[:trades], manual_asset_class: manual_asset_class
        ).call

        render json: {
          imported_count: imported.size,
          investments: imported.map { |i| { id: i.id, name: i.name, asset_class: i.asset_class, realized_pnl: i.realized_pnl.to_s } }
        }
      rescue ArgumentError => e
        render json: { error: e.message }, status: :unprocessable_entity
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
        cred.auto_import_pnl = ActiveModel::Type::Boolean.new.cast(params[:auto_import_pnl]) if params.key?(:auto_import_pnl)
        cred.save!

        # Settings changed — force a fresh token fetch under the new config next time it's needed.
        BrokerAccessToken.where(user: current_user, broker: DhanTokenService::BROKER).delete_all

        render json: credential_json(cred).merge(message: "Broker settings saved")
      end

      private

      def snapshot_service
        @snapshot_service ||= BrokerSnapshotSyncService.new(current_user, broker: DhanTokenService::BROKER)
      end

      # Best-effort — a snapshot refresh failing shouldn't fail the token refresh itself.
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

      # Not a background job — this is the honest version: it only fires when the
      # user (or the page) actually calls refresh_token. A real scheduled sync
      # would need Solid Queue recurring wiring, which isn't set up yet.
      def run_auto_import_if_enabled
        cred = BrokerCredential.find_by(user: current_user, broker: DhanTokenService::BROKER)
        return unless cred&.auto_import_pnl?

        from = 7.days.ago.to_date.to_s
        to = Date.current.to_s
        result = DhanDataService.new.trade_history_all(from_date: from, to_date: to)
        return if result[:truncated]

        DhanInvestmentImportService.new(current_user, from_date: from, to_date: to, trades: result[:trades]).call
      rescue StandardError => e
        Rails.logger.warn("[DhanController] auto-import on refresh failed: #{e.message}")
      end
    end
  end
end
