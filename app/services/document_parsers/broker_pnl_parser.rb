module DocumentParsers
  class BrokerPnlParser < BaseParser
    def parse(document)
      document.file.open do |f|
        text = ocr.extract_text(f.path)
        
        {
          broker_name: extract_broker_name(text),
          financial_year: extract_fy(text),
          
          # Equity (STCG & LTCG)
          equity_stcg_turnover: extract_amount(text, /STCG.*?Turnover.*?([\d,]+\.\d{2})/i),
          equity_stcg_profit: extract_amount(text, /STCG.*?Net Profit.*?([\d,]+\.\d{2})/i),
          equity_ltcg_turnover: extract_amount(text, /LTCG.*?Turnover.*?([\d,]+\.\d{2})/i),
          equity_ltcg_profit: extract_amount(text, /LTCG.*?Net Profit.*?([\d,]+\.\d{2})/i),
          
          # F&O
          fo_turnover: extract_amount(text, /F&O.*?Turnover.*?([\d,]+\.\d{2})/i) || extract_amount(text, /Futures & Options.*?Turnover.*?([\d,]+\.\d{2})/i),
          fo_profit: extract_amount(text, /F&O.*?Net Profit.*?([\d,]+\.\d{2})/i) || extract_amount(text, /Futures & Options.*?Net Profit.*?([\d,]+\.\d{2})/i),
          
          # Charges
          total_charges: extract_amount(text, /Total Charges.*?([\d,]+\.\d{2})/i),

          raw_text: text[0..2000]
        }
      end
    end

    def validate!(extracted_data)
      []
    end

    private

    def extract_broker_name(text)
      if text.match?(/Zerodha/i)
        "Zerodha"
      elsif text.match?(/Upstox/i)
        "Upstox"
      elsif text.match?(/Groww/i)
        "Groww"
      elsif text.match?(/Dhan/i)
        "Dhan"
      else
        "Unknown Broker"
      end
    end

    def extract_fy(text)
      match = text.match(/(\d{4}-\d{2})/)
      match ? match[1] : nil
    end

    def extract_amount(text, regex)
      match = text.match(regex)
      return 0.0 unless match
      match[1].gsub(',', '').to_f
    end
  end
end
