module Api
  module V1
    class LoansController < BaseController
      before_action :set_loan, only: [ :show, :destroy ]

      def index
        scope = current_user.loan_accounts.includes(:emi_schedules)
        @pagy, @loans = pagy(scope)

        render json: paginated_response(@pagy, @loans.map { |loan| serialize_summary(loan) })
      end

      def show
        render json: serialize_detail(@loan)
      end

      def create
        loan = current_user.loan_accounts.build(loan_params)
        loan.status = "active"
        loan.save!
        
        AmortizationService.new(loan).generate_schedule!
        
        render json: serialize_summary(loan.reload), status: :created
      end

      def destroy
        @loan.destroy!
        head :no_content
      end

      private

      def set_loan
        @loan = current_user.loan_accounts.find(params[:id])
      end

      def loan_params
        params.permit(:name, :lender, :principal_amount, :interest_rate,
                      :tenure_months, :start_date, :loan_type)
      end

      def serialize_summary(loan)
        if loan.emi_schedules.loaded?
          schedules = loan.emi_schedules.to_a
          paid_count = schedules.count { |emi| emi.status == "paid" }
          total_interest = schedules.sum(&:interest_component)
        else
          paid_count = loan.emi_schedules.where(status: "paid").count
          total_interest = loan.emi_schedules.sum(:interest_component)
        end
        outstanding_principal = loan.outstanding_principal.presence || loan.principal_amount

        loan.as_json.merge(
          "emiAmount" => loan.emi_amount.to_s,
          "outstandingPrincipal" => outstanding_principal.to_s,
          "totalInterest" => total_interest.to_s,
          "totalAmount" => (loan.principal_amount.to_d + total_interest).to_s,
          "isActive" => loan.status == "active",
          "paidEmiCount" => paid_count,
          "remainingEmiCount" => loan.tenure_months - paid_count
        )
      end

      def serialize_detail(loan)
        serialize_summary(loan).merge("emis" => loan.emi_schedules.order(:installment_number))
      end
    end
  end
end
