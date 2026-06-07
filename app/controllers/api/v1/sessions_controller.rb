module Api
  module V1
    class SessionsController < BaseController
      skip_before_action :authenticate_user!, only: [ :show, :create ]

      def show
        if current_user
          render json: serialize(current_user)
        else
          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end

      def create
        user = User.find_by(email: params.require(:email).to_s.downcase.strip)

        if user&.authenticate(params.require(:password))
          token = generate_token(user.id)
          render json: serialize(user).merge(token: token)
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def destroy
        head :no_content
      end

      private

      def generate_token(user_id)
        JWT.encode({ user_id: user_id, exp: 24.hours.from_now.to_i }, Rails.application.credentials.secret_key_base || 'secret', 'HS256')
      end

      def serialize(user)
        { id: user.id, name: user.name, email: user.email }
      end
    end
  end
end
