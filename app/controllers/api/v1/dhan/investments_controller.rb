module Api
  module V1
    module Dhan
      class InvestmentsController < BaseController
        def pnl_summary
          from = params[:from_date] || 30.days.ago.to_date.to_s
          to = params[:to_date] || Date.current.to_s
          result = DhanDataService.new.trade_history_all(from_date: from, to_date: to)
          render json: {
            from_date: from,
            to_date: to,
            truncated: result[:truncated],
            segments: DhanPnlSummaryService.new(result[:trades]).call
          }
        end

        def sync
          from = params[:from_date] || 1.month.ago.to_date.to_s
          to = params[:to_date] || Date.current.to_s
          DhanSyncJob.perform_later(user_id: current_user.id, from_date: from, to_date: to)
          render json: { message: "Sync started in background", status: "running" }
        end

        def sync_status
          status = Rails.cache.read("dhan_sync:#{current_user.id}:status")
          trades = Rails.cache.read("dhan_sync:#{current_user.id}:trades") || 0
          render json: { status: status || "none", trades_imported: trades }
        end

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
      end
    end
  end
end
