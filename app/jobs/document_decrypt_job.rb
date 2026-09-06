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
      Tempfile.create(["decrypted", File.extname(encrypted.path)]) do |temp_file|
        decrypted_path = temp_file.path
        temp_file.close

        # Ensure qpdf is available in the environment, fallback if missing
        success = system(
          "qpdf", "--password=#{password}", "--decrypt",
          encrypted.path, decrypted_path
        )

        if success
          File.open(decrypted_path) do |f|
            doc.file.attach(
              io: f,
              filename: "decrypted_#{doc.metadata['original_name']}",
              content_type: doc.file.content_type
            )
          end
          # Now parse it
          OcrProcessingJob.perform_later(doc.id)
        else
          doc.update!(
            status: :failed,
            metadata: (doc.metadata || {}).merge("decrypt_error" => "Password mismatch — verify PAN & DOB in profile")
          )
        end
      end
    end
  end
end
