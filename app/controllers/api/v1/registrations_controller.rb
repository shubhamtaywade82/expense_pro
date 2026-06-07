module Api
  module V1
    class RegistrationsController < BaseController
      skip_before_action :authenticate_user!, only: [ :create ]

      def create
        user = User.new(registration_params)

        if user.save
          reset_session
          session[:user_id] = user.id
          render json: { id: user.id, name: user.name, email: user.email }, status: :created
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
