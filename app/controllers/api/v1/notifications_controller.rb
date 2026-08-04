# app/controllers/api/v1/notifications_controller.rb
module Api
  module V1
    class NotificationsController < BaseController
      before_action :set_notification, only: [:show, :mark_read, :archive]

      # GET /api/v1/notifications
      def index
        @notifications = current_user.notifications
                                     .where(archived: params[:archived] == 'true')
                                     .order(created_at: :desc)
        
        pagy, notifications = pagy(@notifications, items: 20)
        
        render json: {
          notifications: notifications.as_json(include_payload: true),
          meta: pagy_metadata(pagy),
          unread_count: current_user.unread_notification_count
        }
      end

      # GET /api/v1/notifications/unread_count
      def unread_count
        render json: {
          count: current_user.unread_notification_count
        }
      end

      # POST /api/v1/notifications/mark_all_read
      def mark_all_read
        current_user.mark_all_notifications_read!
        render json: { success: true, message: "All notifications marked as read" }
      end

      # PATCH/PUT /api/v1/notifications/:id/mark_read
      def mark_read
        @notification.mark_read!
        render json: { success: true, notification: @notification.as_json(include_payload: true) }
      end

      # PATCH/PUT /api/v1/notifications/:id/archive
      def archive
        @notification.archive!
        render json: { success: true, notification: @notification.as_json(include_payload: true) }
      end

      # DELETE /api/v1/notifications/:id
      def destroy
        @notification.destroy
        render json: { success: true, message: "Notification deleted" }
      end

      private

      def set_notification
        @notification = current_user.notifications.find(params[:id])
      end

      def notification_params
        params.require(:notification).permit(:read, :archived, :viewed_at)
      end
    end
  end
end
