module DocumentParsers
  class PanParser < BaseParser
    PAN_REGEX = /[A-Z]{5}[0-9]{4}[A-Z]{1}/
    DOB_REGEX = %r{\b(\d{2}[/-]\d{2}[/-]\d{4})\b}

    def parse(document)
      document.file.open do |f|
        text = ocr.extract_text(f.path)

        {
          pan_number: extract_pattern(text, PAN_REGEX),
          dob: extract_pattern(text, DOB_REGEX),
          raw_text: text[0..1000]
        }
      end
    end

    def validate!(extracted_data)
      errors = []
      if extracted_data[:pan_number].blank?
        errors << "Could not extract a valid 10-digit PAN number from the image."
      end
      errors
    end

    private

    def extract_pattern(text, regex)
      match = text.to_s.match(regex)
      match ? match[0].strip : nil
    end
  end
end
