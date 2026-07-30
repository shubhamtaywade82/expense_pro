module Api
  module V1
    class TaxDocumentsController < ApplicationController
      before_action :authenticate_request

      def create
        documents = []
        errors_list = []

        Array(params[:files]).each do |uploaded_file|
          doc = current_user.tax_documents.new(
            document_type: params[:document_type],
            financial_year: params[:financial_year] || TaxCalculatorService.default_financial_year,
            file: uploaded_file,
            metadata: {
              original_name: uploaded_file.original_filename,
              uploaded_at: Time.current.iso8601
            }
          )

          if doc.save
            documents << doc
            enqueue_processing(doc)
          else
            errors_list << { file: uploaded_file.original_filename, errors: doc.errors.full_messages }
          end
        end

        render json: {
          uploaded: documents.map { |d| document_json(d) },
          failed: errors_list
        }, status: documents.any? ? :created : :unprocessable_entity
      end

      def index
        docs = current_user.tax_documents
                           .for_fy(params[:financial_year] || TaxCalculatorService.default_financial_year)
                           .order(created_at: :desc)

        render json: {
          documents: docs.map { |d| document_json(d) }
        }
      end

      def verify
        doc = current_user.tax_documents.find(params[:id])
        doc.update!(
          status: :verified,
          extracted_data: params[:extracted_data] || doc.extracted_data,
          verified_at: Time.current
        )

        render json: document_json(doc)
      end

      def correct
        doc = current_user.tax_documents.find(params[:id])
        doc.update!(
          extracted_data: params[:extracted_data],
          status: :verified,
          verified_at: Time.current,
          metadata: (doc.metadata || {}).merge("corrected_by_user" => true)
        )

        render json: document_json(doc)
      end

      def preview
        doc = current_user.tax_documents.find(params[:id])
        if doc.preview_image.attached?
          redirect_to rails_blob_url(doc.preview_image, disposition: "inline")
        else
          redirect_to rails_blob_url(doc.file, disposition: "inline")
        end
      end

      def destroy
        doc = current_user.tax_documents.find(params[:id])
        doc.file.purge_later if doc.file.attached?
        doc.preview_image.purge_later if doc.preview_image.attached?
        doc.destroy
        head :no_content
      end

      private

      def enqueue_processing(doc)
        # Mock for now, will implement active jobs later
        if doc.requires_decryption?
          doc.update!(status: :decrypting)
        elsif doc.requires_ocr?
          doc.update!(status: :processing)
        else
          doc.update!(status: :verified)
        end
      end

      def document_json(doc)
        {
          id: doc.id,
          document_type: doc.document_type,
          display_name: doc.metadata&.dig("original_name"),
          financial_year: doc.financial_year,
          status: doc.status,
          size_kb: doc.file.attached? ? (doc.file.byte_size / 1024.0).round(1) : 0,
          extracted_data: doc.extracted_data,
          reconciliation: doc.reconciliation,
          preview_url: preview_api_v1_tax_document_path(doc),
          created_at: doc.created_at
        }
      end
    end
  end
end
