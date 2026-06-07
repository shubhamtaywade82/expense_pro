module Api
  module V1
    class BillsController < BaseController
      before_action :set_bill, only: [ :update, :destroy, :toggle_paid ]

      def index
        render json: current_user.monthly_bills.includes(:category).active.ordered.map { |bill| serialize(bill) }
      end

      def create
        bill = current_user.monthly_bills.build(bill_params)
        bill.save!
        render json: serialize(bill), status: :created
      end

      def update
        @bill.update!(bill_params)
        render json: serialize(@bill)
      end

      def destroy
        @bill.update!(is_active: false)
        head :no_content
      end

      def toggle_paid
        @bill.update!(is_paid: !@bill.is_paid)
        render json: serialize(@bill)
      end

      private

      def set_bill
        @bill = current_user.monthly_bills.find(params[:id])
      end

      def bill_params
        params.permit(:category_id, :name, :amount, :due_date, :reminder_days, :notes)
      end

      def serialize(bill)
        bill.as_json.merge("categoryName" => bill.category.name)
      end
    end
  end
end
