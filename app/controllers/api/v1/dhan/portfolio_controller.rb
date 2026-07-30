module Api
  module V1
    module Dhan
      class PortfolioController < BaseController
        def profile
          render json: DhanDataService.new.profile
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

        def fund_limits
          render json: DhanDataService.new.fund_limits
        end

        def ledger
          from = params[:from_date] || 30.days.ago.to_date.to_s
          to = params[:to_date] || Date.current.to_s
          render json: DhanDataService.new.ledger(from_date: from, to_date: to)
        end
      end
    end
  end
end
