# Documents attached to a settlement case (creditor notice, offer letter,
# approval email, receipts, settlement letter, NOC). Files are stored via
# Active Storage; parsed details land in `extracted`.
class CreateSettlementDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :settlement_documents do |t|
      t.references :user, null: false, foreign_key: true
      t.references :settlement_case, null: false, foreign_key: true

      t.integer :document_type, null: false, default: 6  # creditor_notice, offer_letter, ..., other
      t.string  :title, null: false
      t.integer :status, null: false, default: 0        # pending / received / verified
      t.jsonb   :extracted, default: {}, null: false
      t.text    :notes

      t.timestamps
    end

    add_index :settlement_documents, [:settlement_case_id, :document_type], name: "idx_settl_docs_case_on_type"
  end
end
