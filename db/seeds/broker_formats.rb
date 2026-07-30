[
  { broker_name: "Zerodha",
    mapping: { "trade_date" => "trade_date", "symbol" => "symbol", "trade_type" => "trade_type",
               "quantity" => "quantity", "price" => "price", "amount" => "amount" },
    normalization: { date_format: "%Y-%m-%d", buy_values: ["buy"], sell_values: ["sell"] } },

  { broker_name: "Angel One",
    mapping: { "trade_date" => "Trade Date", "symbol" => "Scrip Name", "trade_type" => "Buy/Sell",
               "quantity" => "Quantity", "price" => "Rate", "amount" => "Net Amount" },
    normalization: { date_format: "%d-%b-%Y", buy_values: ["Buy","B"], sell_values: ["Sell","S"] } },

  { broker_name: "Upstox",
    mapping: { "trade_date" => "tradeDate", "symbol" => "instrumentToken", "trade_type" => "transactionType",
               "quantity" => "quantity", "price" => "price", "amount" => "amount" },
    normalization: { date_format: "%Y-%m-%d %H:%M:%S", buy_values: ["buy"], sell_values: ["sell"] } },

  { broker_name: "WazirX",
    mapping: { "trade_date" => "Created at", "symbol" => "Market", "trade_type" => "Side",
               "quantity" => "Executed", "price" => "Avg price", "amount" => "Amount" },
    normalization: { date_format: "%Y-%m-%d %H:%M:%S", buy_values: ["buy"], sell_values: ["sell"] } },
].each { |attrs| BrokerFormatProfile.create!(attrs.merge(approved: true)) }
