module Api
  module V1
    # The settlement pipeline: cases, their offers, contributions,
    # documents and the final payment that closes a debt.
    class SettlementCasesController < BaseController
      before_action :set_case, only: %i[show update destroy record_payment]

      def index
        scope = current_user.settlement_cases.includes(:debt_account, :settlement_offers)
        scope = scope.open if params[:open_only] == "true"
        scope = scope.where(status: params[:status]) if params[:status].present?

        render_camel_json scope.order(:stage, :current_claim_paise).map { |c| case_payload(c) }
      end

      def show
        render_camel_json case_payload(@case).merge(
          "offers" => @case.settlement_offers.order(offered_on: :desc).map { |o| offer_payload(o) },
          "contributions" => @case.settlement_contributions.latest_first.map { |c| c.as_json.merge("amount" => c.amount.to_f) },
          "payments" => @case.settlement_payments.latest_first.map { |p| p.as_json.merge("totalPaid" => p.total_paid.to_f) },
          "documents" => @case.settlement_documents.map { |d| document_payload(d) },
          "scenarioTable" => DebtClearanceService.new(current_user).scenario_table(@case)
        )
      end

      def create
        account = current_user.debt_accounts.find(params[:debt_account_id])
        stage = DebtQueueRanker.new(current_user).stage_for(
          current_user.settlement_cases.new(debt_account: account, current_claim_paise: paise(params[:current_claim] || account.current_balance.to_f))
        )

        settlement_case = current_user.settlement_cases.create!(case_params.merge(
          debt_account: account,
          original_claim_paise: paise(params[:original_claim] || params[:current_claim] || account.current_balance.to_f),
          current_claim_paise: paise(params[:current_claim] || account.current_balance.to_f),
          stage: stage
        ))

        render_camel_json case_payload(settlement_case), status: :created
      end

      def update
        @case.update!(update_params)
        render_camel_json case_payload(@case)
      end

      def destroy
        @case.destroy!
        head :no_content
      end

      # POST /api/v1/settlement_cases/:id/record_payment
      def record_payment
        offer = @case.settlement_offers.find(params[:settlement_offer_id]) if params[:settlement_offer_id].present?

        result = SettlementPaymentService.record(
          user: current_user,
          settlement_case: @case,
          settlement_offer: offer,
          paid_on: parse_date(params[:paid_on]) || Date.current,
          payment_mode: params[:payment_mode] || "neft",
          reference_number: params[:reference_number],
          notes: params[:notes],
          sync_to_expenses: ActiveModel::Type::Boolean.new.cast(params.fetch(:sync_to_expenses, true))
        )

        if result[:success]
          render_camel_json({ payment: result[:payment].as_json.merge("totalPaid" => result[:payment].total_paid.to_f) }, status: :created)
        else
          render_camel_json({ error: result[:error] }, status: :unprocessable_entity)
        end
      end

      private

      def set_case
        @case = current_user.settlement_cases.find(params[:id])
      end

      def case_params
        permitted = params.permit(
          :started_on, :original_claim, :current_claim,
          :target_min_percentage, :target_max_percentage,
          :service_fee_percentage, :gst_percentage,
          :monthly_contribution, :eligibility_threshold_percentage,
          :status, :priority, :notes
        )

        permitted[:started_on] = parse_date(permitted[:started_on]) || Date.current if permitted.key?(:started_on)
        permitted[:monthly_contribution] = paise(permitted[:monthly_contribution]) if permitted.key?(:monthly_contribution)

        permitted.except(:original_claim, :current_claim)
      end

      # On update only; creation sets claims/stage from the debt account.
      def update_params
        permitted = case_params
        if params.key?(:current_claim)
          permitted[:current_claim_paise] = paise(params[:current_claim])
          permitted[:stage] = DebtQueueRanker.new(current_user).stage_for(
            current_user.settlement_cases.new(
              debt_account: @case.debt_account,
              current_claim_paise: permitted[:current_claim_paise],
              status: permitted[:status] || @case.status
            )
          ).to_s
        end
        permitted[:original_claim_paise] = paise(params[:original_claim]) if params.key?(:original_claim)
        permitted
      end

      def case_payload(settlement_case)
        settlement_case.as_json.merge(
          "startedOn" => settlement_case.started_on&.to_s,
          "originalClaim" => settlement_case.original_claim.to_f,
          "currentClaim" => settlement_case.current_claim.to_f,
          "monthlyContribution" => settlement_case.monthly_contribution.to_f,
          "estimatedTotal" => settlement_case.estimated_total / 100.0,
          "estimatedTotalMin" => settlement_case.estimated_total(percentage: settlement_case.target_min_percentage) / 100.0,
          "contributedAmount" => settlement_case.contributed_amount_paise / 100.0,
          "settlementFund" => settlement_case.settlement_fund_paise / 100.0,
          "fundingProgress" => settlement_case.funding_progress,
          "eligible" => settlement_case.eligible?,
          "debtAccount" => settlement_case.debt_account.as_json.merge(
            "currentBalance" => settlement_case.debt_account.current_balance.to_f,
            "monthlyCashflowDemand" => settlement_case.debt_account.monthly_cashflow_demand.round(2)
          )
        )
      end

      def offer_payload(offer)
        offer.as_json.merge(
          "claimAmount" => offer.claim_amount.to_f,
          "settlementPercentage" => offer.settlement_percentage.to_f,
          "settlementAmount" => offer.settlement_amount.to_f,
          "serviceFee" => offer.service_fee.to_f,
          "gst" => offer.gst.to_f,
          "totalAmount" => offer.total_amount.to_f,
          "expired" => offer.expired?
        )
      end

      def document_payload(document)
        document.as_json.merge(
          "fileAttached" => document.file.attached?,
          "fileUrl" => (Rails.application.routes.url_helpers.rails_blob_path(document.file, only_path: true) if document.file.attached?)
        )
      end

      def paise(value)
        (value.to_f * 100).round
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue Date::Error
        nil
      end
    end
  end
end
