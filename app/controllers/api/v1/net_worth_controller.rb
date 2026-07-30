module Api
  module V1
    class NetWorthController < BaseController
      def show
        render json: NetWorthService.new(current_user).calculate
      end
    end
  end
end
