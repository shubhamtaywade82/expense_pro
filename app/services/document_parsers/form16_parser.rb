module DocumentParsers
  class Form16Parser < BaseParser
    # Basic RegEx patterns for common Form 16 Part A & B fields
    PAN_REGEX = /[A-Z]{5}[0-9]{4}[A-Z]{1}/
    TAN_REGEX = /[A-Z]{4}[0-9]{5}[A-Z]{1}/
    AMOUNT_REGEX = /Rs\.?\s*([\d,]+(?:\.\d{2})?)/i

    def parse(document)
      document.file.open do |f|
        text = ocr.extract_text(f.path)
        
        {
          employer_name: extract_employer_name(text),
          employer_tan: extract_pattern(text, /TAN of the Employer\s*:\s*(#{TAN_REGEX})/i),
          employee_pan: extract_pattern(text, /PAN of the Employee\s*:\s*(#{PAN_REGEX})/i),
          assessment_year: extract_pattern(text, /Assessment Year\s*:\s*(\d{4}-\d{2})/i),
          
          # Part B (Income details)
          gross_salary: extract_amount(text, /Gross Salary\s*(?:.*Rs\.?)?\s*([\d,]+\.\d{2})/i),
          exemptions_10: extract_amount(text, /Exemptions under section 10\s*(?:.*Rs\.?)?\s*([\d,]+\.\d{2})/i),
          standard_deduction: extract_amount(text, /Standard deduction under section 16\(ia\)\s*(?:.*Rs\.?)?\s*([\d,]+\.\d{2})/i),
          income_chargeable_under_salaries: extract_amount(text, /Income chargeable under the head 'Salaries'\s*(?:.*Rs\.?)?\s*([\d,]+\.\d{2})/i),
          
          # Deductions (Chapter VI-A)
          deductions_80c: extract_amount(text, /80C.*?([\d,]+\.\d{2})/i),
          total_chapter_via_deductions: extract_amount(text, /Total deductions under Chapter VI-A\s*(?:.*Rs\.?)?\s*([\d,]+\.\d{2})/i),
          
          # Tax
          total_taxable_income: extract_amount(text, /Total Income\s*(?:.*Rs\.?)?\s*([\d,]+\.\d{2})/i),
          tax_on_total_income: extract_amount(text, /Tax on total income\s*(?:.*Rs\.?)?\s*([\d,]+\.\d{2})/i),
          tax_deducted: extract_amount(text, /Total tax deducted\s*(?:.*Rs\.?)?\s*([\d,]+\.\d{2})/i),

          raw_text: text[0..5000] # store partial raw text for debugging if needed
        }
      end
    end

    def validate!(extracted_data)
      errors = []
      
      if extracted_data[:gross_salary].to_f == 0.0
        errors << "Could not extract Gross Salary. Ensure the document is clear and readable."
      end

      # Mathematical validation
      calc_income = extracted_data[:gross_salary].to_f - extracted_data[:exemptions_10].to_f - extracted_data[:standard_deduction].to_f
      reported_income = extracted_data[:income_chargeable_under_salaries].to_f
      
      if calc_income > 0 && reported_income > 0 && (calc_income - reported_income).abs > 10.0
        errors << "Gross Salary minus exemptions and standard deduction (#{calc_income}) does not match Income Chargeable under Salaries (#{reported_income})"
      end

      errors
    end

    private

    def extract_pattern(text, regex)
      match = text.match(regex)
      match ? match[1].strip : nil
    end

    def extract_amount(text, regex)
      match = text.match(regex)
      return 0.0 unless match
      
      # Clean up commas and convert to float
      match[1].gsub(',', '').to_f
    end

    def extract_employer_name(text)
      # Usually at the top, near Name and address of the Employer
      match = text.match(/Name and address of the Employer\s*\n\s*(.*?)\n/i)
      match ? match[1].strip : "Unknown Employer"
    end
  end
end
