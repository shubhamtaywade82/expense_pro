module Api
  module V1
    class RegistrationsController < BaseController
      skip_before_action :authenticate_user!, only: [ :create ]

      def create
        user = User.new(registration_params)

        if user.save
          token = JWT.encode({ user_id: user.id, exp: 24.hours.from_now.to_i, iat: Time.current.to_i }, jwt_secret, 'HS256')
          render json: { id: user.id, name: user.name, email: user.email, persona: user.persona, token: token }, status: :created
        else
          render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      private

      def registration_params
        params.require(:user).permit(:name, :email, :password)
      end
    end
  end
end
