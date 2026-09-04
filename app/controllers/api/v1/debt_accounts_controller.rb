module Api
  module V1
    # CRUD for the unified debt registry. Balances arrive as major-unit
    # amounts from the frontend and are stored as integer paise.
    class DebtAccountsController < BaseController
      def index
        scope = current_user.debt_accounts.order(:classification, current_balance_paise: :desc)
        scope = scope.where(classification: params[:classification]) if params[:classification].present?
        scope = scope.open if params[:open_only] == "true"

        render_camel_json accounts_payload(scope)
      end

      def create
        account = current_user.debt_accounts.create!(debt_account_params)
        render_camel_json account_payload(account), status: :created
      end

      def update
        account = current_user.debt_accounts.find(params[:id])
        account.update!(debt_account_params)
        render_camel_json account_payload(account)
      end

      def destroy
        current_user.debt_accounts.find(params[:id]).destroy!
        head :no_content
      end

      # POST /api/v1/debt_accounts/:id/snapshot
      # Records a fresh balance reading (statement, notice, credit report).
      def snapshot
        account = current_user.debt_accounts.find(params[:id])
        account.record_snapshot!(
          balance_paise: paise(params[:balance]),
          dpd: params[:dpd].to_i,
          recorded_on: parse_date(params[:recorded_on]) || Date.current,
          source: params[:source] || "manual",
          notes: params[:notes]
        )
        render_camel_json account_payload(account)
      end

      private

      def debt_account_params
        permitted = params.require(:debt_account).permit(
          :name, :lender, :debt_type, :classification, :status,
          :original_principal, :current_balance, :monthly_obligation,
          :interest_rate, :dpd, :formal_notice, :first_defaulted_on,
          :charged_off_on, :last_payment_on, :notes, :priority,
          :loan_account_id, :loan_id
        )

        permitted[:original_principal] = paise(permitted[:original_principal]) if permitted.key?(:original_principal)
        permitted[:current_balance] = paise(permitted[:current_balance]) if permitted.key?(:current_balance)
        permitted[:monthly_obligation] = paise(permitted[:monthly_obligation]) if permitted.key?(:monthly_obligation)
        permitted[:formal_notice] = ActiveModel::Type::Boolean.new.cast(permitted[:formal_notice]) if permitted.key?(:formal_notice)
        %i[first_defaulted_on charged_off_on last_payment_on].each do |date_field|
          permitted[date_field] = parse_date(permitted[date_field]) if permitted.key?(date_field)
        end

        permitted
      end

      def accounts_payload(scope)
        scope.map { |a| account_payload(a) }
      end

      def account_payload(account)
        account.as_json.merge(
          "currentBalance" => account.current_balance.to_f,
          "originalPrincipal" => account.original_principal.to_f,
          "monthlyObligation" => account.monthly_obligation&.to_f,
          "monthlyCashflowDemand" => account.monthly_cashflow_demand.round(2),
          "ageInMonths" => account.age_in_months,
          "openCaseId" => account.settlement_cases.open.first&.id
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
