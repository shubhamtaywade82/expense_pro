module DocumentParsers
  class AisParser
    def self.primary_amount_path
      ["total_reported_income"]
    end

    def parse(document)
      file_content = document.file.download
      raw = JSON.parse(file_content)
      ais = raw["ais"] || raw

      {
        pan: raw["pan"],
        financial_year: raw["fy"],

        tds_entries: parse_tds(ais["TDS"]),
        total_tds: sum_amounts(ais["TDS"]),

        interest_income: parse_sft_category(ais["SFT"], "INT"),
        dividend_income: parse_sft_category(ais["SFT"], "DIV"),
        equity_transactions: parse_sft_category(ais["SFT"], "SFT012"),
        mutual_fund_transactions: parse_sft_category(ais["SFT"], "SFT013"),
        property_transactions: parse_sft_category(ais["SFT"], "SFT006"),
        high_value_deposits: parse_sft_category(ais["SFT"], "SFT001"),
        fd_transactions: parse_sft_category(ais["SFT"], "SFT005"),

        total_interest_reported: sum_sft(ais["SFT"], "INT"),
        total_dividend_reported: sum_sft(ais["SFT"], "DIV"),
        total_equity_sale_value: sum_sft_sales(ais["SFT"], "SFT012"),
        total_mf_sale_value: sum_sft_sales(ais["SFT"], "SFT013"),

        total_reported_income: compute_total(ais),
        parsed_at: Time.current.iso8601,
        parser: "ais_v1"
      }
    end

    private

    def parse_tds(entries)
      Array(entries).map do |e|
        {
          section: e["sec"],
          payer_tan: e.dig("payer", "tan"),
          payer_name: e.dig("payer", "name"),
          amount: e["amt"].to_f,
          tds: e["tds"].to_f,
          fy: e["fy"]
        }
      end
    end

    def parse_sft_category(sft, code)
      Array(sft).select { |e| e["code"] == code }.map do |e|
        {
          reporter: e.dig("reporter", "name"),
          pan: e.dig("reporter", "pan"),
          amount: e["amt"].to_f,
          description: e["desc"],
          period: e["period"]
        }
      end
    end

    def sum_sft(sft, code)
      parse_sft_category(sft, code).sum { |e| e[:amount] }
    end

    def sum_sft_sales(sft, code)
      Array(sft).select { |e| e["code"] == code && e["cr"].present? }
                .sum { |e| e["cr"].to_f }
    end

    def sum_amounts(entries)
      Array(entries).sum { |e| e["tds"].to_f }
    end

    def compute_total(ais)
      sum_sft(ais["SFT"], "INT") + sum_sft(ais["SFT"], "DIV")
    end
  end
end
