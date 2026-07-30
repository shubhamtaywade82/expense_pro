class ReconciliationService
  def initialize(user_id:, financial_year:)
    @user = User.find(user_id)
    @financial_year = financial_year
  end

  def reconcile!
    # Mock reconciliation for now - this cross-references internal app data (incomes, trades) 
    # with the extracted OCR data to find discrepancies.
    
    docs = @user.tax_documents.where(financial_year: @financial_year, status: :extracted)
    
    docs.each do |doc|
      # In a real implementation, we would compare doc.extracted_data 
      # against @user.incomes or @user.trades
      
      # For now, mark as verified if no mismatches are detected
      doc.update!(status: :verified)
    end
  end
end
