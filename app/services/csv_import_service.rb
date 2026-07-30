class CsvImportService
  require "csv"

  # Our canonical fields
  CANONICAL = %w[trade_date symbol name trade_type quantity price amount segment charges].freeze

  def initialize(user, broker_name:, asset_class: nil)
    @user = user
    @broker_name = broker_name
    @profile = BrokerFormatProfile.match(broker_name)
    @asset_class = asset_class || @profile&.dig("asset")
  end

  def inspect(file_content)
    rows = parse(file_content)
    {
      detected_delimiter: @delimiter,
      detected_encoding: @encoding,
      headers: rows.headers,
      sample_rows: rows.first(5).map(&:to_h),
      row_count: rows.size,
      suggested_mapping: auto_map(rows.headers),
      matched_profile: @profile&.broker_name
    }
  end

  def import(file_content, mapping:, normalization: {})
    norm = (normalization.presence || @profile&.normalization || {}).symbolize_keys
    rows = parse(file_content)

    imported, skipped, errors = [], 0, []

    rows.each_with_index do |row, i|
      trade = map_row(row, mapping, norm)

      if trade.invalid?
        errors << { row: i + 2, problems: trade.errors }
        next
      end

      # Dedup key: broker + date + symbol + qty + price + side
      key = "#{@broker_name}:#{trade.trade_date}:#{trade.symbol}:#{trade.quantity}:#{trade.price}:#{trade.trade_type}"
      if @user.trades.exists?(broker_import_key: key)
        skipped += 1
        next
      end

      @user.trades.create!(trade.attributes.merge(broker: @broker_name.downcase, broker_import_key: key))
      imported << trade
    end

    { imported: imported.size, skipped_duplicates: skipped, failed: errors.size, errors: errors.first(20) }
  end

  private

  def parse(content)
    @encoding = detect_encoding(content)
    content = content.encode("UTF-8", @encoding, invalid: :replace, undef: :replace)
    @delimiter = detect_delimiter(content)
    CSV.parse(content, headers: true, col_sep: @delimiter, liberal_parsing: true)
  end

  def detect_delimiter(content)
    first_line = content.lines.first
    [",", "\t", ";", "|"].max_by { |d| first_line.count(d) }
  end

  def detect_encoding(content)
    content.valid_encoding? ? content.encoding.to_s : "ISO-8859-1"
  end

  def auto_map(headers)
    mapping = {}
    CANONICAL.each do |field|
      best = headers.max_by { |h| similarity(h, field) }
      mapping[field] = best if best && similarity(best, field) > 0.5
    end
    mapping
  end

  SYNONYMS = {
    "trade_date" => %w[date trade_date tradedate trade\ date txn\ date time created\ at fill\ date],
    "symbol"     => %w[symbol scrip scrip\ name instrument token ticker pair market],
    "trade_type" => %w[type side action buy/sell transaction\ type trade\ type buy_sell],
    "quantity"   => %w[qty quantity qty. nos units executed size],
    "price"      => %w[price rate rate/price avg\ price average\ price fill\ price],
    "amount"     => %w[amount net\ amount value turnover net\ value consideration]
  }.freeze

  def similarity(a, b)
    a = a.to_s.downcase.strip
    return 1.0 if SYNONYMS[b]&.include?(a)
    1.0 - (levenshtein_distance(a, b).to_f / [a.length, b.length].max)
  end
  
  def levenshtein_distance(s, t)
    m = s.length
    n = t.length
    return m if n == 0
    return n if m == 0
    d = Array.new(m+1) {Array.new(n+1)}
    (0..m).each {|i| d[i][0] = i}
    (0..n).each {|j| d[0][j] = j}
    (1..n).each do |j|
      (1..m).each do |i|
        d[i][j] = if s[i-1] == t[j-1]
                    d[i-1][j-1]
                  else
                    [d[i-1][j]+1,d[i][j-1]+1,d[i-1][j-1]+1].min
                  end
      end
    end
    d[m][n]
  end

  def map_row(row, mapping, norm)
    raw_type = row[mapping["trade_type"]].to_s.strip.downcase
    trade_type = norm[:buy_values]&.map(&:downcase)&.include?(raw_type) ? "buy" :
                 norm[:sell_values]&.map(&:downcase)&.include?(raw_type) ? "sell" : nil

    Trade.new(
      user: @user,
      symbol: row[mapping["symbol"]].to_s.strip,
      trade_type: trade_type,
      quantity: parse_number(row[mapping["quantity"]], norm),
      price: parse_number(row[mapping["price"]], norm),
      amount: parse_number(row[mapping["amount"]], norm),
      trade_date: parse_date(row[mapping["trade_date"]], norm[:date_format])
      # segment: @asset_class
    ).tap { |t| t.amount ||= t.quantity.to_f * t.price.to_f }
  end

  def parse_number(str, norm)
    return 0.0 if str.blank?
    str = str.to_s.gsub(/[^0-9.,\-]/, "")
    str = str.gsub(norm[:thousands_sep] || ",", "").tr(norm[:decimal_sep] || ".", ".") if norm[:thousands_sep]
    str.to_f
  end

  def parse_date(str, format)
    return nil if str.blank?
    format ? Date.strptime(str.to_s.strip, format) : Date.parse(str.to_s.strip)
  rescue ArgumentError
    nil
  end
end
