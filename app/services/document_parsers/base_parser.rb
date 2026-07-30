module DocumentParsers
  class BaseParser
    def parse(document)
      raise NotImplementedError, "Parsers must implement #parse(document)"
    end

    def validate!(extracted_data)
      [] # Returns an array of error messages, empty if valid
    end

    protected

    def ocr
      @ocr ||= OCR::OcrService.new
    end
  end
end
