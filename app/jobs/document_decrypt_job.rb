class DocumentDecryptJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 10.seconds, attempts: 2

  def perform(document_id)
    doc = TaxDocument.find(document_id)
    user = doc.user
    doc.update!(status: :decrypting)

    # Password scheme: PAN (uppercase) + DOB (DDMMYYYY)
    # e.g. ABCDE1234F + 15-08-1990 → ABCDE1234F15081990
    password = "#{user.pan.upcase}#{user.date_of_birth.strftime('%d%m%Y')}"

    doc.file.open do |encrypted|
      decrypted_path = "#{Dir.tmpdir}/decrypted_#{doc.id}#{File.extname(encrypted.path)}"

      # Ensure qpdf is available in the environment, fallback if missing
      success = system(
        "qpdf", "--password=#{password}", "--decrypt",
        encrypted.path, decrypted_path
      )

      if success
        doc.file.attach(
          io: File.open(decrypted_path),
          filename: "decrypted_#{doc.metadata['original_name']}",
          content_type: doc.file.content_type
        )
        # Now parse it
        if doc.document_type == "ais_json"
          doc.update!(status: :processing)
          AisParseJob.perform_later(doc.id)
        else
          OcrProcessingJob.perform_later(doc.id)
        end
      else
        doc.update!(
          status: :failed,
          metadata: (doc.metadata || {}).merge("decrypt_error" => "Password mismatch — verify PAN & DOB in profile")
        )
      end
    ensure
      File.delete(decrypted_path) if defined?(decrypted_path) && decrypted_path && File.exist?(decrypted_path)
    end
  end
end
