module Api
  module V1
    class LoansController < BaseController
      before_action :set_loan, only: [ :show, :update, :destroy, :recalculate_schedule, :import_schedule, :update_schedule ]

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

      def update
        @loan.update!(loan_params)
        AmortizationService.new(@loan).generate_schedule! if params[:regenerate_schedule].to_s == "true"
        render json: serialize_summary(@loan.reload)
      end

      def recalculate_schedule
        revisions = params[:rate_revisions]
        disbursements = params[:disbursements]
        AmortizationService.new(@loan).recalculate_multistage!(
          rate_revisions: revisions,
          disbursements: disbursements
        )
        render json: serialize_detail(@loan.reload)
      end

      def import_schedule
        rows = Array(params[:rows]).map do |row|
          {
            installment_number: row[:installment_number] || row[:installmentNumber] || row[:emi_number] || row[:emiNumber],
            due_date: row[:due_date] || row[:dueDate],
            opening_balance: row[:opening_balance] || row[:openingBalance],
            emi_amount: row[:emi_amount] || row[:emiAmount] || row[:amount],
            principal_component: row[:principal_component] || row[:principalComponent] || row[:principal],
            interest_component: row[:interest_component] || row[:interestComponent] || row[:interest],
            closing_balance: row[:closing_balance] || row[:closingBalance],
            status: row[:status],
            paid_on: row[:paid_on] || row[:paidOn]
          }
        end

        AmortizationService.new(@loan).import_schedule!(rows)
        render json: serialize_detail(@loan.reload)
      end

      def update_schedule
        attrs = params.permit(:due_date, :emi_amount, :principal_component, :interest_component, :status, :paid_on).to_h
        schedule = AmortizationService.new(@loan).update_installment!(params[:schedule_id], attrs)
        render json: schedule
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
                      :tenure_months, :start_date, :loan_type,
                      rate_revisions: [:effective_date, :interest_rate, :strategy],
                      disbursements: [:disbursed_on, :amount, :is_pre_emi])
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
          "remainingEmiCount" => loan.tenure_months.to_i - paid_count,
          "rateRevisions" => loan.rate_revisions || [],
          "disbursements" => loan.disbursements || []
        )
      end

      def serialize_detail(loan)
        serialize_summary(loan).merge("emis" => loan.emi_schedules.order(:installment_number))
      end
    end
  end
end
