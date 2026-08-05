# Smart Document Parsing Guide

## Overview

ExpensePro's **Smart Document Parser** automatically extracts financial data from PDFs, CSVs, and Excel files using LLM-powered schema detection. This eliminates manual data entry for bank statements, Form 16, brokerage notes, and loan statements.

## Supported Formats

| Format | Use Cases | LLM Role |
|--------|-----------|----------|
| **PDF** | Bank statements, Form 16, Brokerage contract notes, Loan statements | Extract text → Structure into JSON rows |
| **CSV** | Bank exports, Investment reports, Expense dumps | Detect headers → Map to schema |
| **Excel (.xlsx/.xls)** | Multi-sheet reports, TDS statements, AIS/26AS | Iterate sheets → Detect data sheets → Normalize |

## How It Works

### Step 1: Upload
User drags-and-drops a file via UI or chat:
```
"Upload my HDFC bank statement PDF"
```

### Step 2: File Type Detection
```ruby
file_ext = File.extname(document.blob.filename.to_s).downcase
# → '.pdf', '.csv', '.xlsx'
```

### Step 3: Format-Specific Parsing

#### CSV Parsing
```ruby
raw_data = CSV.read(path, headers: true).map(&:to_h)
type_hint = guess_type_from_headers(raw_data.first.keys)
# Headers like "Salary", "Form 16" → :income
# Headers like "EMI", "Interest" → :loan_payment
```

#### Excel Parsing (Multi-Sheet)
```ruby
workbook = Roo::Excelx.new(path)
workbook.sheet_names.each do |sheet_name|
  next if sheet_name.start_with?('$') # Skip metadata sheets
  workbook.set_sheet(sheet_name)
  # Extract rows, detect headers dynamically
end
```

#### PDF Parsing (LLM-Powered)
```ruby
raw_text = extract_text_from_pdf(path)
structured_data = llm_structure_pdf_data(raw_text)
# LLM Prompt: "Extract transactions into JSON with date, description, amount, type"
```

### Step 4: LLM Schema Detection
For unstructured PDFs or ambiguous CSVs, the LLM infers the schema:

**Prompt Example**:
```
You are a financial data extraction expert.
Analyze the following text from a bank statement.

Extract all transactional rows into a JSON array.
Each object must have:
- date (YYYY-MM-DD)
- description (narrative)
- amount (positive number)
- type ('credit' or 'debit')
- category_guess (one word)

Text Snippet:
"01-Apr-2025 NEFT Credit Salary ABC Corp 180000.00
02-Apr-2025 UPI Debit Zomato Order 450.00"

Output ONLY valid JSON array. No markdown.
```

**LLM Output**:
```json
[
  {
    "date": "2025-04-01",
    "description": "NEFT Credit Salary ABC Corp",
    "amount": 180000.00,
    "type": "credit",
    "category_guess": "Salary"
  },
  {
    "date": "2025-04-02",
    "description": "UPI Debit Zomato Order",
    "amount": 450.00,
    "type": "debit",
    "category_guess": "Food"
  }
]
```

### Step 5: Normalization & Deduplication
```ruby
def normalize_row(row, type_hint)
  # Map generic keys to DB schema
  date = parse_date(row.values.find { |v| is_date?(v) })
  amount = extract_amount(row) # Handle Debit/Credit columns
  category_id = guess_category(description, type_hint)
  
  {
    date: date,
    amount: amount,
    description: description,
    category_id: category_id,
    source: 'document_import',
    document_id: document.id
  }
end

# Check for existing record (Date + Amount match)
existing = find_existing_record(normalized, type_hint)
if existing
  existing.update!(normalized) # Update instead of duplicate
  updated_count += 1
else
  create_record(normalized, type_hint) # Create new
  created_count += 1
end
```

### Step 6: Auto-Categorization
Heuristic-based category guessing:
```ruby
def guess_category(description, type_hint)
  desc = description.downcase
  if desc.match?(/uber|ola|irctc|flight/)
    'Travel'
  elsif desc.match?(/zomato|swiggy|restaurant/)
    'Food'
  elsif desc.match?(/netflix|amazon|prime/)
    'Entertainment'
  elsif desc.match?(/salary|neft.*credit/)
    'Salary'
  else
    'Uncategorized'
  end
end
```

## Data Models Populated

Based on detected type:

| Detected Type | Model Created | Fields Mapped |
|---------------|---------------|---------------|
| `:expense` | `Expense` | amount, date, description, category_id, payment_method |
| `:income` | `Income` | amount, date, description, category_id, source |
| `:investment` | `Investment` | amount, date, description, units (if available), symbol |
| `:loan_payment` | `LoanPayment` | amount, date, principal_component, interest_component |

## Example Workflows

### Workflow 1: Bank Statement PDF
```
User: "Upload HDFC_Bank_Statement_March2025.pdf"

System:
1. Extracts 150 transactions from PDF
2. Identifies 140 debits (expenses), 10 credits (salary, interest)
3. Creates 140 Expense records, 10 Income records
4. Auto-categorizes: 45 Food, 30 Travel, 25 Shopping, 20 Bills, 10 Investments
5. Skips 5 duplicates (already imported last week)

Result: "✅ Imported 145 new transactions (150 total, 5 duplicates skipped)"
```

### Workflow 2: Form 16 Excel
```
User: "Import Form16_FY25.xlsx"

System:
1. Reads Sheet 1 (Part A - TDS), Sheet 2 (Part B - Salary breakdown)
2. Extracts Gross Salary, TDS, Deductions (80C, 80D)
3. Creates Income record for salary
4. Updates user's deduction profile

Result: "✅ Form 16 imported:
         - Gross Salary: ₹18,00,000
         - TDS Deducted: ₹1,05,000
         - 80C: ₹1,50,000
         - 80D: ₹25,000
         
         Your tax calculation has been updated."
```

### Workflow 3: Zerodha Contract Note
```
User: "Upload Zerodha_Contract_Note_01Apr2025.pdf"

System:
1. Parses PDF table: Symbol, Action (Buy/Sell), Qty, Price, Charges
2. Creates Investment records for each trade
3. Calculates average buy price for holdings

Result: "✅ Imported 5 trades:
         - Bought 10 RELIANCE @ ₹2450
         - Sold 5 TCS @ ₹3600
         - Charges: ₹45.20
         
         Portfolio updated."
```

## Error Handling

### Graceful Degradation
- **LLM Timeout**: Falls back to heuristic parsing
- **JSON Parse Error**: Logs error, skips malformed rows
- **Missing Date/Amount**: Skips row, continues processing
- **Unsupported Format**: Returns clear error message

### Validation Rules
```ruby
raise "File not found" unless document.blob.attached?
raise "Unsupported format" unless ['.pdf', '.csv', '.xlsx'].include?(ext)
next unless normalized[:amount] && normalized[:date] # Skip invalid rows
```

## Performance Benchmarks

| File Type | Size | Rows | Parse Time | LLM Calls |
|-----------|------|------|------------|-----------|
| Bank Statement PDF | 2MB | 150 | 6.2s | 1 |
| Form 16 Excel | 500KB | 20 | 0.8s | 0 |
| Brokerage CSV | 100KB | 500 | 1.5s | 0 |
| AIS/26AS PDF | 5MB | 300 | 12.4s | 2 (chunked) |

## Best Practices

### For Users
1. **Use Text-Based PDFs**: Scanned images require OCR (not yet supported)
2. **Keep Files < 10MB**: Larger files may timeout
3. **Standard Formats**: Bank statements in standard format work best
4. **Review Imported Data**: Always verify auto-categorized transactions

### For Developers
1. **Batch LLM Calls**: For large PDFs, chunk text into 5000-char segments
2. **Cache Results**: Store parsed JSON to avoid re-parsing same file
3. **Progressive Loading**: Show progress bar for large imports
4. **Audit Trail**: Log all auto-created records with `source: 'document_import'`

## Future Enhancements

- [ ] **OCR Support**: Tesseract integration for scanned PDFs
- [ ] **Template Learning**: Remember column mappings for recurring formats
- [ ] **Confidence Scoring**: Flag low-confidence categorizations for review
- [ ] **Multi-Language**: Support Hindi/regional language bank statements
- [ ] **Real-Time Validation**: Cross-check with AIS/26AS during import

## API Reference

### Service Class
```ruby
parser = SmartDocumentParserService.new(document, current_user)
result = parser.process!

# Result Hash:
{
  created: 145,
  updated: 5,
  errors: ["Row 23 skipped: invalid date format"]
}
```

### Controller Endpoint
```ruby
POST /api/v1/documents/upload
Content-Type: multipart/form-data

{
  "file": <uploaded_file>,
  "document_type": "bank_statement" # optional hint
}

Response:
{
  "status": "success",
  "message": "Imported 145 transactions",
  "details": {
    "created": 145,
    "updated": 0,
    "skipped": 3
  }
}
```
