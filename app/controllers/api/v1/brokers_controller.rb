module Api
  module V1
    class BrokersController < BaseController
      before_action :set_credential, only: [
        :status, :profile, :holdings, :positions, :orders,
        :trades, :fund_limits, :ledger, :pnl_summary,
        :import_investments, :import_trades, :sync, :sync_status,
        :update_credential, :destroy_credential
      ]

      # ── Discovery ──

      # GET /api/v1/brokers/available
      def available
        render json: {
          brokers: Brokers::Registry.available_brokers,
          crypto_brokers: Brokers::Registry.crypto_brokers.keys,
          equity_brokers: Brokers::Registry.equity_brokers.keys
        }
      end

      # GET /api/v1/brokers/connected
      def connected
        credentials = current_user.broker_credentials.order(:created_at)
        render json: {
          brokers: credentials.map(&:safe_attributes),
          count: credentials.size
        }
      end

      # ── Credential Management ──

      # POST /api/v1/brokers/connect
      def connect
        broker_type = params[:broker_type]
        adapter_class = Brokers::Registry.adapter_for(broker_type)

        credential = current_user.broker_credentials.find_or_initialize_by(
          broker_type: broker_type
        )

        credential.assign_attributes(credential_params(adapter_class))
        credential.status = :active

        if credential.save
          # Validate credentials by making a test API call
          begin
            result = credential.authenticate!
            render json: {
              success: true,
              broker: credential.safe_attributes,
              account_info: result[:account_info]
            }, status: :created
          rescue Brokers::AuthenticationError => e
            credential.update!(status: :error)
            render json: { success: false, error: e.message }, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: credential.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/brokers/:broker_type/credential
      def update_credential
        adapter_class = Brokers::Registry.adapter_for(@credential.broker_type)
        @credential.assign_attributes(credential_params(adapter_class))

        if @credential.save
          render json: { success: true, broker: @credential.safe_attributes }
        else
          render json: { errors: @credential.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/brokers/:broker_type
      def destroy_credential
        @credential.update!(status: :revoked)
        head :no_content
      end

      # ── Account Data (proxied through adapter) ──

      # GET /api/v1/brokers/:broker_type/status
      def status
        valid = @credential.adapter.token_valid?
        render json: {
          broker_type: @credential.broker_type,
          display_name: @credential.adapter.class.display_name,
          status: @credential.status,
          token_valid: valid,
          token_expires_at: @credential.token_expires_at,
          last_sync_at: @credential.last_sync_at
        }
      end

      # GET /api/v1/brokers/:broker_type/profile
      def profile
        render json: @credential.adapter.profile
      end

      # GET /api/v1/brokers/:broker_type/holdings
      def holdings
        holdings = @credential.adapter.holdings
        # Also sync snapshot
        BrokerSnapshotSyncService.new(current_user, broker: @credential.broker_type)
                                 .sync_holdings!(holdings.map(&:raw_data))
        render json: { holdings: holdings.map(&:to_h) }
      end

      # GET /api/v1/brokers/:broker_type/positions
      def positions
        return render json: { positions: [], note: "This broker does not support positions" } unless
          @credential.adapter.supports_positions?

        positions = @credential.adapter.positions
        BrokerSnapshotSyncService.new(current_user, broker: @credential.broker_type)
                                 .sync_positions!(positions.map(&:raw_data))
        render json: { positions: positions.map(&:to_h) }
      end

      # GET /api/v1/brokers/:broker_type/fund_limits
      def fund_limits
        render json: @credential.adapter.fund_limits
      end

      # GET /api/v1/brokers/:broker_type/pnl_summary
      def pnl_summary
        from = params[:from_date] || 30.days.ago.to_date.to_s
        to = params[:to_date] || Date.current.to_s
        render json: @credential.adapter.pnl_summary(from_date: Date.parse(from), to_date: Date.parse(to))
      end

      # ── Import Operations ──

      # POST /api/v1/brokers/:broker_type/import_investments
      def import_investments
        from_date = params[:from_date] || 90.days.ago.to_date.to_s
        to_date = params[:to_date] || Date.current.to_s

        BrokerImportJob.perform_later(
          user_id: current_user.id,
          broker_type: @credential.broker_type,
          from_date: from_date,
          to_date: to_date,
          import_type: "investments"
        )

        render json: {
          status: "queued",
          broker: @credential.broker_type,
          message: "Investment import started for #{@credential.adapter.class.display_name}"
        }, status: :accepted
      end

      # POST /api/v1/brokers/:broker_type/import_trades
      def import_trades
        from_date = params[:from_date] || 90.days.ago.to_date.to_s
        to_date = params[:to_date] || Date.current.to_s

        BrokerImportJob.perform_later(
          user_id: current_user.id,
          broker_type: @credential.broker_type,
          from_date: from_date,
          to_date: to_date,
          import_type: "trades"
        )

        render json: {
          status: "queued",
          broker: @credential.broker_type,
          message: "Trade import started"
        }, status: :accepted
      end

      # POST /api/v1/brokers/:broker_type/sync
      def sync
        BrokerSyncJob.perform_later(
          user_id: current_user.id,
          broker_type: @credential.broker_type
        )

        render json: { status: "queued", broker: @credential.broker_type }, status: :accepted
      end

      # GET /api/v1/brokers/:broker_type/sync_status
      def sync_status
        cache_key = "broker:#{@credential.broker_type}:#{current_user.id}"
        render json: {
          broker: @credential.broker_type,
          status: Rails.cache.read("#{cache_key}:sync_status") || "idle",
          data: Rails.cache.read("#{cache_key}:sync_data"),
          error: Rails.cache.read("#{cache_key}:sync_error")
        }
      end

      private

      def set_credential
        @credential = current_user.broker_credentials.find_by!(
          broker_type: params[:broker_type],
          status: [:active, :expired]  # allow expired so user can see status
        )
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Broker not connected. Use POST /api/v1/brokers/connect" },
               status: :not_found
      end

      def credential_params(adapter_class)
        permitted = adapter_class.required_credentials + [:config]
        params.permit(*permitted).slice(*permitted.map(&:to_s))
      end
    end
  end
end
