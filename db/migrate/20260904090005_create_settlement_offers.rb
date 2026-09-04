# A concrete offer on the table for a SettlementCase: creditor claim at a
# given settlement percentage, plus the fee/GST breakdown it implies.
#
# Outstanding -> claim -> negotiation -> offer -> accepted -> payment ->
# document -> closed. The claim amount never automatically becomes the
# settlement amount; that only happens through accepted offers here.
class CreateSettlementOffers < ActiveRecord::Migration[8.0]
  def change
    create_table :settlement_offers do |t|
      t.references :settlement_case, null: false, foreign_key: true

      t.date    :offered_on, null: false
      t.bigint  :claim_amount_paise, null: false, default: 0
      t.decimal :settlement_percentage, precision: 5, scale: 2, null: false, default: "0.0"

      # Recomputed from claim x percentage x case fee/GST terms whenever
      # the offer is saved (see SettlementCalculator).
      t.bigint  :settlement_amount_paise, null: false, default: 0
      t.bigint  :service_fee_paise, null: false, default: 0
      t.bigint  :gst_paise, null: false, default: 0
      t.bigint  :total_amount_paise, null: false, default: 0

      t.date    :valid_until
      t.integer :status, null: false, default: 0   # proposed / countered / accepted / rejected / expired
      t.date    :accepted_on
      t.string  :reference_number
      t.text    :notes

      t.timestamps
    end

    add_index :settlement_offers, [:settlement_case_id, :status]
  end
end
