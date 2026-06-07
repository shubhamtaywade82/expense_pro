module Api
  module V1
    class LoansController < BaseController
      before_action :set_loan, only: [ :show, :destroy ]

      def index
        render json: current_user.loans.includes(:category).map { |loan| serialize_summary(loan) }
      end

      def show
        render json: serialize_detail(@loan)
      end

      def create
        loan = current_user.loans.build(loan_params)
        loan.save!
        render json: serialize_summary(loan), status: :created
      end

      def destroy
        @loan.destroy!
        head :no_content
      end

      private

      def set_loan
        @loan = current_user.loans.find(params[:id])
      end

      def loan_params
        params.permit(:category_id, :name, :lender, :principal_amount, :interest_rate,
                      :tenure_months, :start_date, :loan_type, :notes)
      end

      def serialize_summary(loan)
        paid_count = loan.emi_payments.where(is_paid: true).count
        total_interest = loan.emi_payments.sum(:interest_amount)

        loan.as_json.merge(
          "categoryName" => loan.category.name,
          "categoryColor" => loan.category.color,
          "emiAmount" => loan.emi_amount.to_s,
          "outstandingPrincipal" => loan.outstanding_principal.to_s,
          "totalInterest" => total_interest.to_s,
          "totalAmount" => (loan.principal_amount.to_d + total_interest).to_s,
          "isActive" => paid_count < loan.tenure_months,
          "paidEmiCount" => paid_count,
          "remainingEmiCount" => loan.tenure_months - paid_count
        )
      end

      def serialize_detail(loan)
        serialize_summary(loan).merge("emis" => loan.emi_payments.ordered)
      end
    end
  end
end
