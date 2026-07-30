module DocumentParsers
  class Registry
    def self.for(document_type)
      TaxDocument::OCR_PARSERS[document_type]
    end
  end
end
