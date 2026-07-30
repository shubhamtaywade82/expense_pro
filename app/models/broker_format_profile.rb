class BrokerFormatProfile < ApplicationRecord
  belongs_to :user, optional: true   # nil = system/community preset

  # mapping jsonb: { "trade_date" => "Trade Date", "symbol" => "Scrip", ... }
  # normalization jsonb: { date_format: "%d-%m-%Y", buy_values: ["BUY","B"], ... }

  validates :broker_name, :mapping, presence: true
  scope :community, -> { where(user_id: nil, approved: true) }

  def self.match(broker_name)
    where("LOWER(broker_name) LIKE ?", "%#{broker_name.downcase.squish}%").first ||
      community.where("similarity(broker_name, ?) > 0.4", broker_name)
               .order(Arel.sql("similarity(broker_name, #{connection.quote(broker_name)}) DESC")).first
  end
end
