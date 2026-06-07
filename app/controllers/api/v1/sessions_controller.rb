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
          reset_session
          session[:user_id] = user.id
          render json: serialize(user)
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def destroy
        reset_session
        head :no_content
      end

      private

      def serialize(user)
        { id: user.id, name: user.name, email: user.email }
      end
    end
  end
end
