class AisParseJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 30.seconds, attempts: 2

  def perform(document_id)
    doc = TaxDocument.find(document_id)
    doc.update!(status: :processing)

    parser = DocumentParsers::AisParser.new
    extracted = parser.parse(doc)

    doc.update!(
      extracted_data: extracted.deep_stringify_keys,
      status: :extracted
    )

    ReconciliationJob.perform_later(user_id: doc.user_id, financial_year: doc.financial_year) if defined?(ReconciliationJob)
  rescue => e
    doc.update!(status: :failed, metadata: (doc.metadata || {}).merge("parse_error" => e.message))
    raise
  ensure
    Current.reset
  end
end
