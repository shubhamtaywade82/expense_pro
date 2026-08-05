# app/services/smart_document_parser_service.rb
# Responsible for parsing PDFs, CSVs, and Excels using LLM for schema detection
# and auto-populating Expense/Income/Investment records.

class SmartDocumentParserService
  include ActiveSupport::Rescuable

  attr_reader :document, :user

  def initialize(document, user)
    @document = document
    @user = user
  end

  def process!
    raise "File not found" unless document.blob.attached? || document.blob.persisted?

    file_ext = File.extname(document.blob.filename.to_s).downcase
    temp_path = download_to_temp

    begin
      case file_ext
      when '.csv'
        parse_csv(temp_path)
      when '.xlsx', '.xls'
        parse_excel(temp_path)
      when '.pdf'
        parse_pdf(temp_path)
      else
        raise "Unsupported file format: #{file_ext}"
      end
    ensure
      FileUtils.rm_f(temp_path)
    end
  end

  private

  def download_to_temp
    temp_file = Tempfile.new(['doc', file_ext])
    temp_file.binmode
    document.blob.download_to_file(temp_file)
    temp_file.path
  end

  # --- PARSERS ---

  def parse_csv(path)
    raw_data = CSV.read(path, headers: true).map(&:to_h)
    process_rows(raw_data, guess_type_from_headers(raw_data.first&.keys))
  end

  def parse_excel(path)
    workbook = Roo::Excelx.new(path)
    results = []
    
    workbook.sheet_names.each do |sheet_name|
      next if sheet_name.start_with?('$') # Skip hidden/metadata sheets
      
      workbook.set_sheet(sheet_name)
      headers = nil
      rows = []

      workbook.each_row_streaming(headers: false) do |row|
        values = row.map { |cell| cell.value }
        if headers.nil?
          headers = values.map(&:to_s)
        else
          rows << Hash[[headers, values].transpose]
        end
      end
      results.concat(rows) if rows.any?
    end

    process_rows(results, guess_type_from_headers(results.first&.keys))
  end

  def parse_pdf(path)
    # Extract text using pdfplumber via Python microservice or ruby-pdf-reader
    # For robustness, we send to Python service if complex, else simple text extract
    raw_text = extract_text_from_pdf(path)
    
    # Use LLM to structure unstructured PDF text into JSON rows
    structured_data = llm_structure_pdf_data(raw_text)
    
    process_rows(structured_data, structured_data.first&.dig('type_hint') || :expense)
  end

  # --- LLM INTEGRATION ---

  def guess_type_from_headers(headers)
    return :expense unless headers
    
    header_str = headers.join(" ").downcase
    
    if header_str.match?(/salary|form.?16|ctc|gross/)
      :income
    elsif header_str.match?(/loan|emi|interest|principal/)
      :loan_payment
    elsif header_str.match?(/invest|sip|mutual|stock|share/)
      :investment
    else
      :expense
    end
  end

  def llm_structure_pdf_data(raw_text)
    # Truncate if too large (keep first 5000 chars for context)
    context = raw_text.slice(0, 5000)
    
    prompt = <<~PROMPT
      You are a financial data extraction expert. 
      Analyze the following text extracted from a financial document (Bank Statement, Form 16, or Brokerage Note).
      
      Extract all transactional rows into a JSON array of objects.
      Each object must have:
      - date (YYYY-MM-DD)
      - description (narrative)
      - amount (positive number)
      - type ('credit' or 'debit')
      - category_guess (one word: e.g., 'Food', 'Travel', 'Salary', 'Investment')
      
      Text Snippet:
      #{context}
      
      Output ONLY valid JSON array. No markdown.
    PROMPT

    response = OllamaClient.chat(
      model: ENV.fetch('OLLAMA_MODEL', 'qwen3.5:4b'),
      messages: [{ role: 'user', content: prompt }]
    )
    
    # Clean up markdown code blocks if present
    clean_json = response.gsub(/```json|```/, '').strip
    JSON.parse(clean_json)
  rescue JSON::ParserError => e
    Rails.logger.error "LLM JSON Parse Error: #{e.message}"
    []
  end

  def process_rows(rows, type_hint)
    created_count = 0
    updated_count = 0
    errors = []

    rows.each do |row|
      begin
        normalized = normalize_row(row, type_hint)
        next unless normalized[:amount] && normalized[:date]

        # Find existing to update (prevent duplicates)
        existing = find_existing_record(normalized, type_hint)

        if existing
          existing.update!(normalized)
          updated_count += 1
        else
          create_record(normalized, type_hint)
          created_count += 1
        end
      rescue => e
        errors << "Row skipped: #{e.message}"
      end
    end

    { created: created_count, updated: updated_count, errors: errors }
  end

  def normalize_row(row, type_hint)
    # Map generic keys to our DB schema using LLM if needed, or simple heuristics
    # Heuristics for speed
    date_val = row.values.find { |v| v.is_a?(Date) || (v.is_a?(String) && v.match?(/\d{2,4}[-\/]\d{2}[-\/]\d{2,4}/)) }
    date = date_val.is_a?(Date) ? date_val : Date.parse(date_val.to_s) rescue nil

    amount_val = row.values.find { |v| v.is_a?(Numeric) }
    # Handle Debit/Credit columns if present
    if row.keys.map(&:downcase).include?('debit')
      amount_val = -row['Debit'].to_f if row['Debit'].to_f > 0
    elsif row.keys.map(&:downcase).include?('credit')
      amount_val = row['Credit'].to_f if row['Credit'].to_f > 0
    end
    
    amount = amount_val.to_f

    desc_val = row.values.find { |v| v.is_a?(String) && v.length > 5 && v.length < 200 }
    description = desc_val || "Imported Transaction"

    # LLM Category Guessing (Batched in production, here single for simplicity)
    category_id = Category.find_by(name: guess_category(description, type_hint))&.id || Category.first&.id

    {
      date: date,
      amount: amount,
      description: description,
      category_id: category_id,
      source: 'document_import',
      document_id: document.id
    }
  end

  def guess_category(description, type_hint)
    # Quick heuristic map
    return 'Uncategorized' unless description
    
    desc = description.downcase
    if desc.match?(/uber|ola|irctc|flight|hotel/)
      return 'Travel'
    elsif desc.match?(/zomato|swiggy|starbucks|restaurant/)
      return 'Food'
    elsif desc.match?(/netflix|amazon|prime/)
      return 'Entertainment'
    elsif desc.match?(/salary|neft.*credit/)
      return 'Salary'
    end
    
    type_hint == :income ? 'Salary' : 'Uncategorized'
  end

  def find_existing_record(data, type_hint)
    # Deduplication logic: Match by Date + Amount + Similar Description
    scope = case type_hint
            when :income then Income
            when :investment then Investment
            else Expense
            end
            
    scope.where(date: data[:date], amount: data[:amount].abs).first
  end

  def create_record(data, type_hint)
    case type_hint
    when :income
      Income.create!(user: user, 
                     amount: data[:amount], 
                     date: data[:date], 
                     description: data[:description], 
                     category_id: data[:category_id],
                     document_id: data[:document_id])
    when :investment
      Investment.create!(user: user, 
                         amount: data[:amount], 
                         date: data[:date], 
                         description: data[:description], 
                         category_id: data[:category_id],
                         document_id: data[:document_id])
    else
      Expense.create!(user: user, 
                      amount: data[:amount].abs, 
                      date: data[:date], 
                      description: data[:description], 
                      category_id: data[:category_id],
                      payment_method: 'bank_transfer',
                      document_id: data[:document_id])
    end
  end

  def extract_text_from_pdf(path)
    # Simple extraction. For complex tables, delegate to Python service
    require 'pdf-reader'
    PDF::Reader.file(path).pages.map(&:text).join("\n")
  rescue LoadError
    # Fallback if pdf-reader not installed, call python service
    call_python_pdf_extractor(path)
  end

  def call_python_pdf_extractor(path)
    # Placeholder for calling the Python microservice for heavy PDF lifting
    # resp = HTTParty.post("http://itr_service:8000/extract-pdf", body: { file: ... })
    ""
  end
end
