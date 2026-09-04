module Api
  module V1
    # Paper trail for a settlement: creditor notices, offer letters,
    # approvals, receipts, settlement letters and NOCs.
    class SettlementDocumentsController < BaseController
      before_action :set_case

      def index
        documents = @case.settlement_documents.order(created_at: :desc)
        render_camel_json documents.map { |d| document_payload(d) }
      end

      # Accepts multipart (file) or metadata-only payloads.
      def create
        document = @case.settlement_documents.new(document_params)
        document.user = current_user
        document.file.attach(params[:file]) if params[:file].present?
        document.save!

        render_camel_json document_payload(document), status: :created
      end

      def destroy
        @case.settlement_documents.find(params[:id]).destroy!
        head :no_content
      end

      private

      def set_case
        @case = current_user.settlement_cases.find(params[:settlement_case_id])
      end

      def document_params
        permitted = params.permit(:title, :document_type, :status, :notes)
        permitted[:document_type] = permitted[:document_type] || "other"
        permitted[:status] = permitted[:status].presence || (params[:file].present? ? "received" : "pending")
        permitted
      end

      def document_payload(document)
        document.as_json.merge(
          "fileAttached" => document.file.attached?,
          "fileUrl" => (Rails.application.routes.url_helpers.rails_blob_path(document.file, only_path: true) if document.file.attached?)
        )
      end
    end
  end
end
