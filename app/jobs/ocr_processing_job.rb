class OcrProcessingJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 30.seconds, attempts: 2

  def perform(document_id)
    doc = TaxDocument.find(document_id)
    doc.update!(status: :processing)

    parser_class = doc.parser
    unless parser_class
      doc.update!(status: :verified)
      return
    end

    parser = parser_class.constantize.new
    extracted = parser.parse(doc)

    # Run parser-specific validation
    validation_errors = parser.respond_to?(:validate!) ? parser.validate!(extracted) : []

    if validation_errors.empty?
      doc.update!(
        extracted_data: extracted.deep_stringify_keys,
        status: :extracted
      )
    else
      doc.update!(
        extracted_data: extracted.deep_stringify_keys,
        status: :mismatch,
        reconciliation: { "validation_errors" => validation_errors }
      )
    end

    # Generate preview thumbnail
    generate_preview(doc)

    # Note: ReconciliationJob is not fully implemented yet, but we trigger it here
    ReconciliationJob.perform_later(user_id: doc.user_id, financial_year: doc.financial_year) if defined?(ReconciliationJob)
  rescue => e
    doc.update!(status: :failed, metadata: (doc.metadata || {}).merge("ocr_error" => e.message))
    raise
  ensure
    Current.reset
  end

  private

  def generate_preview(doc)
    doc.file.open do |f|
      if doc.file.content_type == "application/pdf"
        thumb_path = "#{Dir.tmpdir}/thumb_#{doc.id}.png"
        success = system("pdftoppm", "-png", "-f", "1", "-l", "1", "-r", "72", f.path, thumb_path.gsub(".png", ""))
        
        # the output file will be named like thumb_1-1.png
        output_file = "#{thumb_path.gsub('.png', '')}-1.png"
        if success && File.exist?(output_file)
          doc.preview_image.attach(io: File.open(output_file), filename: "preview.png")
          File.delete(output_file)
        end
      end
    end
  rescue StandardError => e
    Rails.logger.error("Failed to generate preview for doc #{doc.id}: #{e.message}")
  end
end
