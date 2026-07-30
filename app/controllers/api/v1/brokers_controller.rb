module Api
  module V1
    class BrokersController < BaseController
      rescue_from StandardError, with: :render_service_unavailable
      rescue_from Brokers::Registry::AdapterNotRegisteredError, with: :render_bad_request

      before_action :resolve_adapter, only: %i[profile positions holdings orders trade_book trade_history fund_limits ledger pnl_summary import_to_investments sync sync_status import_trades pnl_report]
      before_action :require_connected, only: %i[profile positions holdings orders trade_book trade_history fund_limits ledger pnl_summary import_to_investments import_trades pnl_report]

      # Broker registration & metadata
      def index
        adapters = Brokers::Registry.registered_keys.map do |key|
          adapter = Brokers::Registry.for(key)
          cred = BrokerCredential.find_by(user: current_user, broker: key)
          connected = BrokerAccessToken.valid?(current_user, broker: key)
          {
            broker: key,
            name: adapter.broker_name,
            connected: connected,
            configured: cred.present?,
            client_id: cred&.client_id
          }
        end
        render json: { brokers: adapters }
      end

      # Credential CRUD
      def credential_show
        cred = BrokerCredential.find_or_initialize_by(user: current_user, broker: params[:broker])
        render json: credential_json(cred)
      end

      def credential_update
        cred = BrokerCredential.find_or_initialize_by(user: current_user, broker: params[:broker])
        cred.client_id = params[:client_id] if params.key?(:client_id)
        cred.token_service_url = params[:token_service_url] if params.key?(:token_service_url)
        cred.token_service_secret = params[:token_service_secret] if params[:token_service_secret].present?
        cred.fallback_access_token = params[:fallback_access_token] if params[:fallback_access_token].present?
        cred.auto_import_pnl = ActiveModel::Type::Boolean.new.cast(params[:auto_import_pnl]) if params.key?(:auto_import_pnl)
        cred.save!

        BrokerAccessToken.where(user: current_user, broker: params[:broker]).delete_all

        render json: credential_json(cred).merge(message: "Broker settings saved")
      end

      # Token management
      def token_status
        broker = params[:broker]
        adapter = Brokers::Registry.for(broker)
        cred = BrokerCredential.find_by(user: current_user, broker: broker)
        token = BrokerAccessToken.active(current_user, broker: broker)

        if token
          render json: {
            connected: true,
            expires_at: token.expires_at.iso8601,
            client_id: adapter.respond_to?(:client_id) ? adapter.client_id : cred&.client_id,
            token_preview: "#{token.access_token.first(12)}..."
          }
        else
          render json: { connected: false, message: "No valid token. Use refresh to fetch." }
        end
      end

      def refresh_token
        adapter = Brokers::Registry.for(params[:broker])
        adapter.fetch_and_store!
        token = BrokerAccessToken.active(current_user, broker: params[:broker])

        run_auto_import_if_enabled
        sync_snapshots

        render json: {
          connected: true,
          expires_at: token.expires_at.iso8601,
          client_id: adapter.respond_to?(:client_id) ? adapter.client_id : nil,
          message: "Token refreshed successfully"
        }
      rescue => e
        render json: { connected: false, error: e.message }, status: :service_unavailable
      end

      # Portfolio
      def profile
        render json: @adapter.profile
      end

      def positions
        data = @adapter.positions
        snapshot_service.sync_positions!(data)
        render json: data
      end

      def holdings
        data = @adapter.holdings
        snapshot_service.sync_holdings!(data)
        render json: data
      end

      def fund_limits
        render json: @adapter.fund_limits
      end

      def ledger
        from = params[:from_date] || 30.days.ago.to_date.to_s
        to = params[:to_date] || Date.current.to_s
        render json: @adapter.ledger(from_date: from, to_date: to)
      end

      # Trades
      def orders
        render json: @adapter.orders
      end

      def trade_book
        render json: @adapter.trade_book
      end

      def trade_history
        from = params[:from_date] || 30.days.ago.to_date.to_s
        to = params[:to_date] || Date.current.to_s
        result = @adapter.trade_history_all(from_date: from, to_date: to)
        render json: { trades: result[:trades], truncated: result[:truncated] }
      end

      def import_trades
        from = params.require(:from_date)
        to = params.require(:to_date)
        result = @adapter.trade_history_all(from_date: from, to_date: to)
        if result[:truncated]
          render json: { error: "Too many trades in this range — import per month instead" },
                 status: :unprocessable_entity
          return
        end
        count = BrokerTradeImportService.new(current_user, @adapter, result[:trades]).call
        render json: { imported: count, from_date: from, to_date: to }
      end

      def pnl_report
        from = params[:from_date] || 30.days.ago.to_date.to_s
        to = params[:to_date] || Date.current.to_s
        format = params[:format]

        trades = current_user.trades
          .for_broker(params[:broker])
          .for_period(from, to)
          .recent_first

        rows = trades.map { |t| trade_report_row(t) }
        summary = compute_report_summary(rows)

        respond_to do |format|
          format.json { render json: { from_date: from, to_date: to, trades: rows, summary: summary } }
          format.csv { render plain: generate_csv(rows), content_type: "text/csv" }
        end
      end

      # Investments
      def pnl_summary
        from = params[:from_date] || 30.days.ago.to_date.to_s
        to = params[:to_date] || Date.current.to_s
        result = @adapter.trade_history_all(from_date: from, to_date: to)
        render json: {
          from_date: from,
          to_date: to,
          truncated: result[:truncated],
          segments: @adapter.compute_pnl_summary(result[:trades])
        }
      end

      def import_to_investments
        from = params.require(:from_date)
        to = params.require(:to_date)
        manual_asset_class = params[:manual_asset_class].presence

        result = @adapter.trade_history_all(from_date: from, to_date: to)
        if result[:truncated]
          render json: { error: "Too many trades in this range to import accurately. Import per month instead." },
                 status: :unprocessable_entity
          return
        end

        imported = BrokerImportService.new(
          current_user, @adapter, from_date: from, to_date: to,
          trades: result[:trades], manual_asset_class: manual_asset_class
        ).call

        render json: {
          imported_count: imported.size,
          investments: imported.map { |i| { id: i.id, name: i.name, asset_class: i.asset_class, realized_pnl: i.realized_pnl.to_s } }
        }
      end

      def sync
        from = params[:from_date] || 1.month.ago.to_date.to_s
        to = params[:to_date] || Date.current.to_s
        BrokerSyncJob.perform_later(user_id: current_user.id, broker: params[:broker], from_date: from, to_date: to)
        render json: { message: "Sync started in background", status: "running" }
      end

      def sync_status
        status = Rails.cache.read("broker_sync:#{current_user.id}:#{params[:broker]}:status")
        trades = Rails.cache.read("broker_sync:#{current_user.id}:#{params[:broker]}:trades") || 0
        render json: { status: status || "none", trades_imported: trades }
      end

      private

      def resolve_adapter
        @adapter = Brokers::Registry.for(params[:broker])
        @broker_key = params[:broker]
      end

      def require_connected
        return if BrokerAccessToken.valid?(current_user, broker: @broker_key)

        render json: { error: "#{@adapter.broker_name} not connected. Refresh token first." }, status: :unauthorized
      end

      def snapshot_service
        @snapshot_service ||= BrokerSnapshotSyncService.new(current_user, broker: @broker_key)
      end

      def sync_snapshots
        svc = @adapter
        snapshot_service.sync_holdings!(svc.holdings)
        snapshot_service.sync_positions!(svc.positions)
      rescue StandardError => e
        Rails.logger.warn("[BrokersController] snapshot sync failed: #{e.message}")
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

      def render_service_unavailable(exception)
        render json: { error: exception.message }, status: :service_unavailable
      end

      def render_bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end

      def run_auto_import_if_enabled
        return unless params[:broker] == "dhan"

        cred = BrokerCredential.find_by(user: current_user, broker: "dhan")
        return unless cred&.auto_import_pnl?

        from = 7.days.ago.to_date.to_s
        to = Date.current.to_s
        BrokerImportJob.perform_later(user_id: current_user.id, broker: "dhan", from_date: from, to_date: to)
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
        require "csv"
        headers = %w[Trade_Date Symbol Security_ID ISIN Segment Product_Type Instrument Type Quantity Price Total_Value Brokerage STT GST SEBI_Tax Exchange_Charges Stamp_Duty Total_Charges Net_Value Expiry Strike Option_Type]
        CSV.generate(headers: true) do |csv|
          csv << headers
          rows.each { |r| csv << r.values_at(*headers.map(&:underscore).map(&:to_sym)) }
        end
      end
    end
  end
end
