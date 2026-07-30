module Api
  module V1
    class EmiPaymentsController < BaseController
      def pay
        emi = current_user.emi_payments.find(params[:id])
        paid_date = params[:paid_date].presence || Date.current

        if emi.mark_paid!(paid_date)
          render json: emi
        else
          render json: { message: "EMI already paid", emi: emi }
        end
      end
    end
  end
end
