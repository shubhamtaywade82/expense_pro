# frozen_string_literal: true

require "csv"

module Api
  module V1
    class DhanController < BaseController
      rescue_from DhanHQ::Error, with: :render_service_unavailable

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
      end

      def positions
        data = DhanDataService.new.positions
        snapshot_service.sync_positions!(data)
        render json: data
      end

      def holdings
        data = DhanDataService.new.holdings
        snapshot_service.sync_holdings!(data)
        render json: data
      end

      def orders
        svc = DhanDataService.new
        render json: svc.orders
      end

      def trade_book
        svc = DhanDataService.new
        render json: svc.trade_book
      end

      def trade_history
        from = params[:from_date] || 30.days.ago.to_date.to_s
        to   = params[:to_date]   || Date.current.to_s

        result = DhanDataService.new.trade_history_all(from_date: from, to_date: to)
        render json: { trades: result[:trades], truncated: result[:truncated] }
      end

      def fund_limits
        svc = DhanDataService.new
        render json: svc.fund_limits
      end

      def ledger
        from = params[:from_date] || 30.days.ago.to_date.to_s
        to   = params[:to_date]   || Date.current.to_s

        svc = DhanDataService.new
        render json: svc.ledger(from_date: from, to_date: to)
      end

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
      end

      # Full sync: snapshots (holdings + positions) + trade history import.
      # Runs in background job — returns immediately. Poll sync_status to
      # check completion. Defaults to last 30 days.
      # Equity delivery is skipped (needs manual asset class selection) — use
      # Dhan > Trade History > Import for that.
      def sync_investments
        from = params[:from_date] || 1.month.ago.to_date.to_s
        to   = params[:to_date]   || Date.current.to_s

        DhanSyncJob.perform_later(user_id: current_user.id, from_date: from, to_date: to)

        render json: { message: "Sync started in background", status: "running" }
      end

      def sync_status
        status = Rails.cache.read("dhan_sync:#{current_user.id}:status")
        trades = Rails.cache.read("dhan_sync:#{current_user.id}:trades") || 0
        render json: { status: status || "none", trades_imported: trades }
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
      end

      # Persists individual trades from Dhan API into the trades table
      def import_trades
        from = params.require(:from_date)
        to = params.require(:to_date)

        result = DhanDataService.new.trade_history_all(from_date: from, to_date: to)
        if result[:truncated]
          render json: { error: "Too many trades in this range — import per month instead" },
                 status: :unprocessable_entity
          return
        end

        count = DhanTradeImportService.new(current_user, result[:trades]).call
        render json: { imported: count, from_date: from, to_date: to }
      end

      # Trade-level PNL report from persisted trades, matching Dhan XLS structure
      def pnl_report
        from = params[:from_date] || 30.days.ago.to_date.to_s
        to   = params[:to_date]   || Date.current.to_s
        format = params[:format]   # nil (JSON) or "csv"

        trades = current_user.trades
          .for_broker("dhan")
          .for_period(from, to)
          .recent_first

        rows = trades.map { |t| trade_report_row(t) }
        summary = compute_report_summary(rows)

        respond_to do |format|
          format.json { render json: { from_date: from, to_date: to, trades: rows, summary: summary } }
          format.csv { render plain: generate_csv(rows), content_type: "text/csv" }
        end
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
        DhanImportJob.perform_later(user_id: current_user.id, from_date: from, to_date: to)
      end

      def render_service_unavailable(exception)
        render json: { error: exception.message }, status: :service_unavailable
      end

      def trade_report_row(t)
        {
          trade_date: t.trade_date&.strftime("%d-%m-%Y"),
          symbol: t.display_symbol,
          security_id: t.security_id,
          isin: t.isin,
          exchange_segment: t.exchange_segment,
          product_type: t.product_type,
          instrument: t.instrument,
          transaction_type: t.transaction_type,
          quantity: t.traded_quantity&.to_f,
          price: t.traded_price&.to_f,
          total_value: t.total_value,
          brokerage: t.brokerage.to_f,
          stt: t.stt.to_f,
          gst: t.gst.to_f,
          sebi_tax: t.sebi_tax.to_f,
          exchange_charges: t.exchange_charges.to_f,
          stamp_duty: t.stamp_duty.to_f,
          total_charges: t.total_charges,
          net_value: t.net_value,
          expiry: t.expiry_date&.strftime("%d-%m-%Y"),
          strike_price: t.strike_price&.to_f,
          option_type: t.option_type,
          segment: t.segment_key
        }
      end

      def compute_report_summary(rows)
        summary = Hash.new { |h, k| h[k] = { buy_value: 0.0, sell_value: 0.0, charges: 0.0, net_pnl: 0.0, trade_count: 0 } }

        rows.each do |row|
          seg = row[:segment]
          summary[seg][:trade_count] += 1
          summary[seg][:charges] += row[:total_charges].to_f

          if row[:transaction_type] == "BUY"
            summary[seg][:buy_value] += row[:total_value].to_f
          else
            summary[seg][:sell_value] += row[:total_value].to_f
          end
        end

        summary.each do |_seg, s|
          s[:net_pnl] = (s[:sell_value] - s[:buy_value] - s[:charges]).round(2)
          s.transform_values! { |v| v.is_a?(Float) ? v.round(2) : v }
        end

        summary
      end

      def generate_csv(rows)
        headers = %w[Trade_Date Symbol Security_ID ISIN Segment Product_Type Instrument Type Quantity Price Total_Value Brokerage STT GST SEBI_Tax Exchange_Charges Stamp_Duty Total_Charges Net_Value Expiry Strike Option_Type]
        CSV.generate(headers: true) do |csv|
          csv << headers
          rows.each { |r| csv << r.values_at(*headers.map(&:underscore).map(&:to_sym)) }
        end
      end
    end
  end
end
