# The real cash-out event that closes (part of) a settlement: principal
# paid to the creditor plus the service fee and GST paid to the platform.
# Optionally mirrored into the expense ledger for monthly reporting.
class CreateSettlementPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :settlement_payments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :settlement_case, null: false, foreign_key: true
      t.references :settlement_offer, foreign_key: true

      t.date   :paid_on, null: false
      t.bigint :settlement_amount_paise, null: false, default: 0
      t.bigint :service_fee_paise, null: false, default: 0
      t.bigint :gst_paise, null: false, default: 0
      t.bigint :total_paid_paise, null: false, default: 0

      t.string :payment_mode, default: "neft"
      t.string :reference_number
      t.boolean :synced_to_expenses, null: false, default: false
      t.text :notes

      t.timestamps
    end

    add_index :settlement_payments, [:settlement_case_id, :paid_on]
  end
end
