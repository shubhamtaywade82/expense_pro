module DocumentParsers
  class Registry
    def self.for(document_type)
      class_name = TaxDocument::OCR_PARSERS[document_type]
      return nil unless class_name

      class_name.safe_constantize
    end
  end
end
