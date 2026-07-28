module Api
  module V1
    class LoansController < BaseController
      before_action :set_loan, only: [ :show, :destroy ]

      def index
        loans = current_user.loans.includes(:category).to_a
        aggregates = Loan.batch_aggregates(loans)

        render json: loans.map { |loan| serialize_summary(loan, **aggregates[loan]) }
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

      # paid_count/total_interest/outstanding_principal are batched by #index
      # (Loan.batch_aggregates); when absent (show/create — a single loan),
      # each falls back to its own lightweight scalar query.
      def serialize_summary(loan, paid_count: nil, total_interest: nil, outstanding_principal: nil)
        paid_count ||= loan.emi_payments.where(is_paid: true).count
        total_interest ||= loan.emi_payments.sum(:interest_amount)
        outstanding_principal ||= loan.outstanding_principal

        loan.as_json.merge(
          "categoryName" => loan.category.name,
          "categoryColor" => loan.category.color,
          "emiAmount" => loan.emi_amount.to_s,
          "outstandingPrincipal" => outstanding_principal.to_s,
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
