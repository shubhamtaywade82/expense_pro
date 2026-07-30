module Api
  module V1
    module Dhan
      class CredentialController < BaseController
        def show
          cred = BrokerCredential.find_by(user: current_user, broker: DhanTokenService::BROKER)
          render json: credential_json(cred)
        end

        def update
          cred = BrokerCredential.find_or_initialize_by(user: current_user, broker: DhanTokenService::BROKER)
          cred.client_id = params[:client_id] if params.key?(:client_id)
          cred.token_service_url = params[:token_service_url] if params.key?(:token_service_url)
          cred.token_service_secret = params[:token_service_secret] if params[:token_service_secret].present?
          cred.fallback_access_token = params[:fallback_access_token] if params[:fallback_access_token].present?
          cred.auto_import_pnl = ActiveModel::Type::Boolean.new.cast(params[:auto_import_pnl]) if params.key?(:auto_import_pnl)
          cred.save!

          BrokerAccessToken.where(user: current_user, broker: DhanTokenService::BROKER).delete_all

          render json: credential_json(cred).merge(message: "Broker settings saved")
        end
      end
    end
  end
end
