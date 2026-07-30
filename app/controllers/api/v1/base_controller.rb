module Api
  module V1
    class BaseController < ActionController::Base
      skip_before_action :verify_authenticity_token

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable
      rescue_from ActionController::ParameterMissing, with: :render_bad_request

      before_action :underscore_param_keys!
      before_action :authenticate_user!
      before_action :set_current_user

      private

      def set_current_user
        Current.user = current_user
      end

      # The React frontend speaks camelCase (categoryId, expenseDate, ...);
      # ActiveRecord and strong params expect snake_case. Normalize once,
      # at the boundary, instead of mapping keys in every controller.
      def underscore_param_keys!
        self.params = params.deep_transform_keys { |key| key.to_s.underscore }
      end

      def current_user
        return @current_user if @current_user

        header = request.headers["Authorization"]
        return nil unless header.present?

        token = header.split(" ").last
        begin
          decoded = JWT.decode(token, jwt_secret, true, { algorithm: "HS256" })
          @current_user = User.find_by(id: decoded[0]["user_id"])
        rescue JWT::DecodeError
          nil
        end
      end

      def authenticate_user!
        render json: { error: "Unauthorized" }, status: :unauthorized unless current_user
      end

      def jwt_secret
        ENV["JWT_SECRET"].presence or Rails.application.credentials.secret_key_base or
          raise("Missing JWT_SECRET. Set ENV['JWT_SECRET'] or configure secret_key_base in credentials.")
      end

      def render_not_found
        render json: { error: "Not found" }, status: :not_found
      end

      def render_unprocessable(exception)
        render json: { error: exception.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
      end

      def render_bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end
    end
  end
end
