module Api
  module V1
    class AiController < BaseController
      def chat
        params.require(:message)
        
        history = params[:history] || []
        
        # Ensure elements are hashes
        history = history.map(&:to_unsafe_h) if history.is_a?(Array)

        service = AiChatService.new(current_user)
        result = service.chat(params[:message], history)

        render json: result
      rescue => e
        render json: { error: e.message }, status: :internal_server_error
      end
    end
  end
end
