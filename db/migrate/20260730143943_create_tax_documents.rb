class CreateTaxDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :tax_documents do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :financial_year
      t.string :document_type
      t.integer :status
      t.integer :source
      t.jsonb :extracted_data
      t.jsonb :reconciliation
      t.jsonb :metadata
      t.datetime :verified_at

      t.timestamps
    end
  end
end
